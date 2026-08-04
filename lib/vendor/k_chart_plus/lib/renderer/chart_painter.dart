import 'dart:async' show StreamSink;
import 'package:flutter/material.dart';
import 'package:k_chart_plus/extension/canvas_extension.dart';
import 'package:k_chart_plus/utils/number_util.dart';
import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'base_dimension.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

// 데이터 좌표(캔들 인덱스 + 가격) 기준으로 저장 — 화면 픽셀이 아니므로
// 스크롤/줌이 바뀌어도 매 프레임 현재 스케일로 다시 계산되어 항상 올바른
// 위치에 그려진다. index2/price2가 null이면 아직 두 번째 점을 안 찍은
// "그리는 중"인 선이다.
class TrendLine {
  final int index1;
  final double price1;
  final int? index2;
  final double? price2;

  TrendLine(this.index1, this.price1, [this.index2, this.price2]);
}

double? trendLineX;
int? trendLineIndex;

double getTrendLineX() {
  return trendLineX ?? 0;
}

// getMainY(price)의 역함수 — 화면 Y 픽셀을 현재 프레임의 가격 스케일로 가격값 변환
double priceFromY(double y) {
  if (trendLineMax == null ||
      trendLineScale == null ||
      trendLineContentRec == null ||
      trendLineScale == 0) {
    return 0;
  }
  return trendLineMax! - (y - trendLineContentRec!) / trendLineScale!;
}

class ChartPainter extends BaseChartPainter {
  final List<TrendLine> lines; //For TrendLine
  final bool isTrendLine; //For TrendLine
  final List<TrendLine> fiboLines; //For Fibonacci
  final bool isFiboLine; //For Fibonacci
  bool isrecordingCord = false; //For TrendLine
  final double selectY; //For TrendLine
  static get maxScrollX => BaseChartPainter.maxScrollX;
  late BaseChartRenderer mMainRenderer;
  BaseChartRenderer? mVolRenderer;
  Set<BaseChartRenderer> mSecondaryRendererList = {};
  StreamSink<InfoWindowEntity?> sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  int fixedLength;
  final KChartColors chartColors;
  late Paint paintCross, selectPointPaint, selectorBorderPaint;
  late Paint nowPriceSelectorPaint,
      nowPriceSelectorBorderPaint,
      nowPriceLinePaint;
  final KChartStyle chartStyle;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;
  final BaseDimension baseDimension;

  ChartPainter(
    this.chartStyle,
    this.chartColors, {
    required this.lines, //For TrendLine
    required this.isTrendLine, //For TrendLine
    this.fiboLines = const [], //For Fibonacci
    this.isFiboLine = false, //For Fibonacci
    required this.selectY, //For TrendLine
    required this.sink,
    required datas,
    required scaleX,
    required scrollX,
    required isLongPass,
    required selectX,
    required xFrontPadding,
    required this.baseDimension,
    isOnTap,
    isTapShowInfoDialog,
    required this.verticalTextAlignment,
    mainIndicators,
    volHidden,
    secondaryIndicators,
    bool isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
  }) : super(chartStyle,
            datas: datas,
            scaleX: scaleX,
            scrollX: scrollX,
            isLongPress: isLongPass,
            baseDimension: baseDimension,
            isOnTap: isOnTap,
            isTapShowInfoDialog: isTapShowInfoDialog,
            selectX: selectX,
            mainIndicators: mainIndicators,
            volHidden: volHidden,
            secondaryIndicators: secondaryIndicators,
            xFrontPadding: xFrontPadding,
            isLine: isLine) {
    paintCross = Paint()
      ..color = this.chartColors.crossColor
      ..strokeWidth = this.chartStyle.crossWidth
      ..isAntiAlias = true;
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..color = this.chartColors.selectFillColor;
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = this.chartStyle.borderWidth
      ..style = PaintingStyle.stroke
      ..color = this.chartColors.selectBorderColor;

    nowPriceSelectorPaint = Paint()
      ..color = this.chartColors.bgColor
      ..isAntiAlias = true;
    nowPriceSelectorBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = this.chartStyle.borderWidth
      ..isAntiAlias = true;
    nowPriceLinePaint = Paint()
      ..strokeWidth = this.chartStyle.nowPriceLineWidth
      ..isAntiAlias = true;
  }

  @override
  void initChartRenderer() {
    // if (datas != null && datas!.isNotEmpty) {
    //   var t = datas![0];
    //   fixedLength = NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
    // }
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      mainIndicators,
      isLine,
      fixedLength,
      this.chartStyle,
      this.chartColors,
      this.scaleX,
      verticalTextAlignment,
      mBottomPadding,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(
        mVolRect!,
        mVolMaxValue,
        mVolMinValue,
        mChildPadding,
        fixedLength,
        this.chartStyle,
        this.chartColors,
      );
    }
    mSecondaryRendererList.clear();
    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      mSecondaryRendererList.add(SecondaryRenderer(
          mSecondaryRectList[i].mRect,
          mSecondaryRectList[i].mMaxValue,
          mSecondaryRectList[i].mMinValue,
          mChildPadding,
          secondaryIndicators[i],
          fixedLength,
          chartStyle,
          chartColors));
    }
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    Paint mBgPaint = Paint()..color = chartColors.bgColor;
    Rect mainRect =
        Rect.fromLTRB(0, 0, mMainRect.width, mMainRect.height + mTopPadding);
    canvas.drawRect(mainRect, mBgPaint);

    if (mVolRect != null) {
      Rect volRect = Rect.fromLTRB(
        0,
        mVolRect!.top - mChildPadding,
        mVolRect!.width,
        mVolRect!.bottom,
      );
      canvas.drawRect(volRect, mBgPaint);
    }

    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      Rect? mSecondaryRect = mSecondaryRectList[i].mRect;
      Rect secondaryRect = Rect.fromLTRB(
        0,
        mSecondaryRect.top - mChildPadding,
        mSecondaryRect.width,
        mSecondaryRect.bottom,
      );
      canvas.drawRect(secondaryRect, mBgPaint);
    }
    canvas.drawRect(mDateRect, mBgPaint);
  }

  @override
  void drawGrid(canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns);
      mVolRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
      mSecondaryRendererList.forEach((element) {
        element.drawGrid(canvas, mGridRows, mGridColumns);
      });
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);
      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mSecondaryRendererList.forEach((element) {
        element.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      });
    }

    if ((isLongPress == true || (isTapShowInfoDialog && isOnTap)) &&
        isTrendLine == false &&
        isFiboLine == false) {
      drawCrossLine(canvas, size);
    }
    if (isTrendLine == true || isFiboLine == true) {
      drawTrendLines(canvas, size);
    }
    if (isFiboLine == true) drawFiboLines(canvas, size);
    canvas.restore();
  }

  @override
  void drawVerticalText(canvas) {
    var textStyle = getTextStyle(this.chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    mSecondaryRendererList.forEach((element) {
      element.drawVerticalText(canvas, textStyle, mGridRows);
    });
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    if (datas == null) return;

    double columnSpace = size.width / mGridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double x = 0.0;
    double y = 0.0;
    for (var i = 0; i <= mGridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);

      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);

        if (datas?[index] == null) continue;
        TextPainter tp = getTextPainter(getDate(datas![index].time), null);
        y = mDateRect.top + (mBottomPadding - tp.height) / 2;
        x = columnSpace * i - tp.width / 2;
        // Prevent date text out of canvas
        if (x < 0) x = 0;
        if (x > size.width - tp.width) x = size.width - tp.width;
        tp.paint(canvas, Offset(x, y));
      }
    }

//    double translateX = xToTranslateX(0);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStartIndex].id));
//      tp.paint(canvas, Offset(0, y));
//    }
//    translateX = xToTranslateX(size.width);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStopIndex].id));
//      tp.paint(canvas, Offset(size.width - tp.width, y));
//    }
  }

  /// draw the cross line. when user focus
  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);

    TextPainter tp = getTextPainter(
      NumberUtil.formatFixed(point.close, fixedLength),
      chartColors.crossTextColor,
    );
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 5;
    double w2 = 3;
    double r = textHeight / 2 + w2;
    double y = getMainY(point.close);
    double x;
    double space = 4.0;
    bool isLeft = false;
    if (translateXtoX(getX(index)) < mWidth / 2) {
      isLeft = false;
      x = space;
      RRect rect = RRect.fromLTRBR(
        x,
        y - r,
        x + textWidth + 2 * w1,
        y + r,
        Radius.circular(2.0),
      );
      canvas.drawRRect(rect, selectPointPaint);
      canvas.drawRRect(rect, selectorBorderPaint);
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    } else {
      isLeft = true;
      x = mWidth - textWidth - 2 * w1 - space;
      RRect rect = RRect.fromLTRBR(
        x,
        y - r,
        mWidth - space,
        y + r,
        Radius.circular(2.0),
      );
      canvas.drawRRect(rect, selectPointPaint);
      canvas.drawRRect(rect, selectorBorderPaint);
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    }

    TextPainter dateTp =
        getTextPainter(getDate(point.time), chartColors.crossTextColor);
    textWidth = dateTp.width;
    r = textHeight / 2;
    x = translateXtoX(getX(index));
    y = mDateRect.top;

    if (x < textWidth + 2 * w1) {
      x = 1 + textWidth / 2 + w1;
    } else if (mWidth - x < textWidth + 2 * w1) {
      x = mWidth - 1 - textWidth / 2 - w1;
    }

    RRect rectBox = RRect.fromLTRBR(
      x - textWidth / 2 - w1,
      y,
      x + textWidth / 2 + w1,
      mDateRect.bottom,
      Radius.circular(2.0),
    );

    // double baseLine = textHeight / 2;
    canvas.drawRRect(
      rectBox,
      selectPointPaint,
    );
    canvas.drawRRect(
      rectBox,
      selectorBorderPaint,
    );

    dateTp.paint(
      canvas,
      Offset(
        x - textWidth / 2,
        mDateRect.top + (mDateRect.height - dateTp.height) / 2,
      ),
    );

    //Long press to display the details of this data
    sink.add(InfoWindowEntity(point, isLeft: isLeft));
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //Long press to display the data in the press
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    //Release to display the last data
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    mSecondaryRendererList.forEach((element) {
      element.drawText(canvas, data, x);
    });
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine == true) return;
    //plot maxima and minima
    double x = translateXtoX(getX(mMainMinIndex));
    double y = getMainY(mMainLowMinValue);
    if (x < mWidth / 2) {
      //draw right
      TextPainter tp = getTextPainter(
        "── " + (NumberUtil.formatFixed(mMainLowMinValue, fixedLength) ?? ''),
        chartColors.minColor,
      );
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
        (NumberUtil.formatFixed(mMainLowMinValue, fixedLength) ?? '') + " ──",
        chartColors.minColor,
      );
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMainMaxIndex));
    y = getMainY(mMainHighMaxValue);
    if (x < mWidth / 2) {
      //draw right
      TextPainter tp = getTextPainter(
        "── " + (NumberUtil.formatFixed(mMainHighMaxValue, fixedLength) ?? ''),
        chartColors.maxColor,
      );
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
        (NumberUtil.formatFixed(mMainHighMaxValue, fixedLength) ?? '') + " ──",
        chartColors.maxColor,
      );
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  @override
  void drawNowPrice(Canvas canvas) {
    if (!this.showNowPrice) {
      return;
    }

    if (datas == null) {
      return;
    }

    double value = datas!.last.close;
    double y = getMainY(value);

    //view display area boundary value drawing
    if (y > getMainY(mMainLowMinValue)) {
      y = getMainY(mMainLowMinValue);
    }

    if (y < getMainY(mMainHighMaxValue)) {
      y = getMainY(mMainHighMaxValue);
    }

    Color priceColor = value >= datas!.last.open
        ? this.chartColors.nowPriceUpColor
        : this.chartColors.nowPriceDnColor;

    nowPriceSelectorBorderPaint.color = priceColor;
    nowPriceLinePaint.color = priceColor;

    //first draw the horizontal line
    canvas.drawDashLine(
      Offset(0, y),
      Offset(-mTranslateX + mWidth / scaleX, y),
      nowPriceLinePaint,
    );

    //repaint the background and text
    TextPainter tp = getTextPainter(
      NumberUtil.formatFixed(value, fixedLength) ?? '',
      priceColor,
    );

    double paddingX = 3, paddingY = 1.5;
    double space = 5.0;
    double offsetX;
    switch (verticalTextAlignment) {
      case VerticalTextAlignment.left:
        // offsetX = paddingX;
        offsetX = space;
        break;
      case VerticalTextAlignment.right:
        offsetX = mWidth - tp.width - paddingX * 2 - space;
        break;
    }

    double top = y - tp.height / 2;
    RRect rect = RRect.fromLTRBR(
      offsetX,
      top - paddingY,
      offsetX + tp.width + paddingX * 2,
      top + tp.height + paddingY * 2,
      Radius.circular(2.0),
    );
    canvas.drawRRect(
      rect,
      nowPriceSelectorPaint,
    );
    canvas.drawRRect(
      rect,
      nowPriceSelectorBorderPaint,
    );
    tp.paint(
      canvas,
      Offset(offsetX + paddingX, top),
    );
  }

  //For TrendLine
  void drawTrendLines(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    Paint paintY = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    double x = getX(index);
    trendLineX = x;
    trendLineIndex = index;

    double y = selectY;
    // getMainY(point.close);

    // K-line chart vertical line
    canvas.drawLine(
      Offset(x, mTopPadding),
      Offset(x, size.height),
      paintY,
    );
    Paint paintX = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    Paint paint = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-mTranslateX, y),
      Offset(-mTranslateX + mWidth / scaleX, y),
      paintX,
    );
    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          height: 15.0 * scaleX,
          width: 15.0,
        ),
        paint,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          height: 10.0,
          width: 10.0 / scaleX,
        ),
        paint,
      );
    }
    if (lines.isNotEmpty) {
      lines.forEach((element) {
        // 매 프레임 현재 스케일로 x/y를 다시 계산 — 캔들과 동일한 좌표계를
        // 쓰므로 스크롤/줌해도 항상 원래 지점(인덱스+가격)에 붙어 있는다.
        final p1 = Offset(getX(element.index1), getMainY(element.price1));
        final hasSecondPoint = element.index2 != null && element.price2 != null;
        final p2 = hasSecondPoint
            ? Offset(getX(element.index2!), getMainY(element.price2!))
            : Offset(x, y);
        canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = Colors.yellow
              ..strokeWidth = 2);
      });
    }
  }

  static const List<double> _fiboRatios = [
    0,
    0.236,
    0.382,
    0.5,
    0.618,
    0.786,
    1
  ];

  //For Fibonacci
  void drawFiboLines(Canvas canvas, Size size) {
    if (fiboLines.isEmpty) return;
    final labelStyle = getTextStyle(chartColors.trendLineColor);
    final left = getX(mStartIndex);
    final right = getX(mStopIndex);

    for (final element in fiboLines) {
      final hasSecondPoint = element.index2 != null && element.price2 != null;
      if (!hasSecondPoint) continue; // 두 번째 점 찍기 전엔 레벨을 그릴 기준이 없음

      final price1 = element.price1;
      final price2 = element.price2!;
      for (final ratio in _fiboRatios) {
        final price = price1 + (price2 - price1) * ratio;
        final y = getMainY(price);
        canvas.drawLine(
          Offset(left, y),
          Offset(right, y),
          Paint()
            ..color = chartColors.trendLineColor.withValues(alpha: 0.6)
            ..strokeWidth = 1,
        );
        final priceLabel =
            NumberUtil.format(price, fixedLength) ?? price.toStringAsFixed(0);
        final tp = TextPainter(
          text: TextSpan(
            text: '${(ratio * 100).toStringAsFixed(1)}%  $priceLabel',
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(right - tp.width - 4, y - tp.height - 2));
      }
    }
  }

  ///draw cross lines
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);
    double x = getX(index);
    double y = getMainY(point.close);

    // K-line chart vertical line
    canvas.drawDashLine(
      Offset(x, 0),
      Offset(x, size.height),
      paintCross,
    );

    // K-line chart horizontal line
    canvas.drawDashLine(
      Offset(-mTranslateX, y),
      Offset(-mTranslateX + mWidth / scaleX, y),
      paintCross,
    );

    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), height: 4.0 * scaleX, width: 4.0),
        paintCross,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), height: 4.0, width: 4.0 / scaleX),
        paintCross,
      );
    }
  }

  TextPainter getTextPainter(text, color) {
    if (color == null) {
      color = this.chartColors.defaultTextColor;
    }
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(int? date) => dateFormat(
        DateTime.fromMillisecondsSinceEpoch(
            date ?? DateTime.now().millisecondsSinceEpoch),
        mFormats,
      );

  double getMainY(double y) => mMainRenderer.getY(y);

  /// Whether the point is in the SecondaryRect
  // bool isInSecondaryRect(Offset point) {
  //   // return mSecondaryRect.contains(point) == true);
  //   return false;
  // }

  /// Whether the point is in MainRect
  bool isInMainRect(Offset point) {
    return mMainRect.contains(point);
  }
}
