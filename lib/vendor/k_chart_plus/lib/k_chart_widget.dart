import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'renderer/base_dimension.dart';

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn
  ];
}

typedef WidgetDetailBuilder = Widget Function(KLineEntity entity);

/// 외부에서 그려진 추세선을 지울 수 있게 해주는 컨트롤러 (For TrendLine).
/// KChartWidget 내부 상태(lines)는 private State라 직접 접근이 안 되므로
/// 이 컨트롤러를 통해서만 clear()를 위임한다.
class TrendLineController {
  VoidCallback? _clearLines;

  void _bind(VoidCallback clear) => _clearLines = clear;

  void clear() => _clearLines?.call();
}

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final List<MainIndicator> mainIndicators;
  final TrendLineController? trendLineController; //For TrendLine

  ///warning only using MA, BOLL, SAR
  final bool volHidden;
  final List<SecondaryIndicator> secondaryIndicators;

  ///SecondaryState { MACD, KDJ, RSI, WR, CCI }
  // final Function()? onSecondaryTap;
  final bool isLine;
  final bool
      isTapShowInfoDialog; //Whether to enable click to display detailed data
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material Style Information Popup
  final List<String> timeFormat;
  final double mBaseHeight;
  final double? mSecondaryHeight;

  // It will be called when the screen scrolls to the end.
  // If true, it will be scrolled to the end of the right side of the screen.
  // If it is false, it will be scrolled to the end of the left side of the screen.
  final Function(bool)? onLoadMore;

  final int fixedLength;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final KChartColors chartColors;
  final KChartStyle chartStyle;
  final VerticalTextAlignment verticalTextAlignment;
  final bool isTrendLine;
  final bool isFiboLine; //For Fibonacci
  final double xFrontPadding;
  final WidgetDetailBuilder detailBuilder;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    required this.detailBuilder,
    required this.isTrendLine,
    this.isFiboLine = false, //For Fibonacci
    this.xFrontPadding = 100,
    this.mainIndicators = const [],
    this.secondaryIndicators = const [],
    // this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.fixedLength = 2,
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.right,
    this.mBaseHeight = 360,
    this.mSecondaryHeight,
    this.trendLineController, //For TrendLine
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  final StreamController<InfoWindowEntity?> mInfoWindowStream =
      StreamController<InfoWindowEntity?>();
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  AnimationController? _controller;
  Animation<double>? aniX;

  //For TrendLine
  List<TrendLine> lines = [];
  List<TrendLine> fiboLines = []; //For Fibonacci
  double? changeinXposition;
  double? changeinYposition;
  double mSelectY = 0.0;
  bool waitingForOtherPairofCords = false;
  bool enableCordRecord = false;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false, isOnTap = false;

  @override
  void initState() {
    super.initState();
    widget.trendLineController?._bind(() => setState(() {
          lines.clear();
          fiboLines.clear();
          waitingForOtherPairofCords = false;
        })); //For TrendLine + Fibonacci
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    mInfoWindowStream.sink.close();
    mInfoWindowStream.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final BaseDimension baseDimension = BaseDimension(
      mBaseHeight: widget.mBaseHeight,
      mSecondaryHeight: widget.mSecondaryHeight ?? widget.mBaseHeight * .2,
      volHidden: widget.volHidden,
      secondaryIndicators: widget.secondaryIndicators,
      mainIndicators: widget.mainIndicators,
    );
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      baseDimension: baseDimension,
      lines: lines, //For TrendLine
      fiboLines: fiboLines, //For Fibonacci
      sink: mInfoWindowStream.sink,
      xFrontPadding: widget.xFrontPadding,
      isTrendLine: widget.isTrendLine, //For TrendLine
      isFiboLine: widget.isFiboLine, //For Fibonacci
      selectY: mSelectY, //For TrendLine
      datas: widget.datas,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      isOnTap: isOnTap,
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainIndicators: widget.mainIndicators,
      volHidden: widget.volHidden,
      secondaryIndicators: widget.secondaryIndicators,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      fixedLength: widget.fixedLength,
      verticalTextAlignment: widget.verticalTextAlignment,
    );

    return GestureDetector(
      onTapUp: (details) {
        // if (!widget.isTrendLine && widget.onSecondaryTap != null && _painter.isInSecondaryRect(details.localPosition)) {
        //   widget.onSecondaryTap!();
        // }

        if (!widget.isTrendLine &&
            !widget.isFiboLine &&
            _painter.isInMainRect(details.localPosition)) {
          isOnTap = true;
          if (mSelectX != details.localPosition.dx &&
              widget.isTapShowInfoDialog) {
            mSelectX = details.localPosition.dx;
            notifyChanged();
          }
        }
        if ((widget.isTrendLine || widget.isFiboLine) &&
            !isLongPress &&
            enableCordRecord) {
          enableCordRecord = false;
          final int index = trendLineIndex ?? 0;
          final double price = priceFromY(mSelectY);
          final targetList = widget.isFiboLine ? fiboLines : lines;
          if (!waitingForOtherPairofCords) {
            targetList.add(TrendLine(index, price));
          }

          if (waitingForOtherPairofCords) {
            var a = targetList.last;
            targetList.removeLast();
            targetList.add(TrendLine(a.index1, a.price1, index, price));
            waitingForOtherPairofCords = false;
          } else {
            waitingForOtherPairofCords = true;
          }
          notifyChanged();
        }
      },
      onHorizontalDragDown: (details) {
        isOnTap = false;
        _stopAnimation();
        _onDragChanged(true);
      },
      onHorizontalDragUpdate: (details) {
        if (isScale || isLongPress) return;
        mScrollX = ((details.primaryDelta ?? 0) / mScaleX + mScrollX)
            .clamp(0.0, ChartPainter.maxScrollX)
            .toDouble();
        notifyChanged();
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        var velocity = details.velocity.pixelsPerSecond.dx;
        _onFling(velocity);
      },
      onHorizontalDragCancel: () => _onDragChanged(false),
      onScaleStart: (_) {
        isScale = true;
      },
      onScaleUpdate: (details) {
        if (isDrag || isLongPress) return;
        mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
        notifyChanged();
      },
      onScaleEnd: (_) {
        isScale = false;
        _lastScale = mScaleX;
      },
      onLongPressStart: (details) {
        isOnTap = false;
        isLongPress = true;
        final isDrawing = widget.isTrendLine || widget.isFiboLine;
        if ((mSelectX != details.localPosition.dx ||
                mSelectY != details.globalPosition.dy) &&
            !isDrawing) {
          mSelectX = details.localPosition.dx;
          notifyChanged();
        }
        //For TrendLine / Fibonacci
        if (isDrawing && changeinXposition == null) {
          mSelectX = changeinXposition = details.localPosition.dx;
          mSelectY = changeinYposition = details.globalPosition.dy;
          notifyChanged();
        }
        //For TrendLine / Fibonacci
        if (isDrawing && changeinXposition != null) {
          changeinXposition = details.localPosition.dx;
          changeinYposition = details.globalPosition.dy;
          notifyChanged();
        }
      },
      onLongPressMoveUpdate: (details) {
        final isDrawing = widget.isTrendLine || widget.isFiboLine;
        if ((mSelectX != details.localPosition.dx ||
                mSelectY != details.globalPosition.dy) &&
            !isDrawing) {
          mSelectX = details.localPosition.dx;
          mSelectY = details.localPosition.dy;
          notifyChanged();
        }
        if (isDrawing) {
          mSelectX = mSelectX + (details.localPosition.dx - changeinXposition!);
          changeinXposition = details.localPosition.dx;
          mSelectY =
              mSelectY + (details.globalPosition.dy - changeinYposition!);
          changeinYposition = details.globalPosition.dy;
          notifyChanged();
        }
      },
      onLongPressEnd: (details) {
        isLongPress = false;
        enableCordRecord = true;
        mInfoWindowStream.sink.add(null);
        notifyChanged();
      },
      child: Stack(
        children: <Widget>[
          CustomPaint(
            size: Size(double.infinity, baseDimension.mDisplayHeight),
            painter: _painter,
          ),
          if (widget.showInfoDialog) _buildInfoDialog()
        ],
      ),
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(
      CurvedAnimation(parent: _controller!.view, curve: widget.flingCurve),
    );
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
      stream: mInfoWindowStream.stream,
      builder: (context, snapshot) {
        if ((!isLongPress && !isOnTap) ||
            widget.isLine == true ||
            !snapshot.hasData ||
            snapshot.data?.kLineEntity == null) {
          return const SizedBox();
        }
        KLineEntity entity = snapshot.data!.kLineEntity;
        if (snapshot.data!.isLeft) {
          return Positioned(
            left: 10.0,
            child: widget.detailBuilder.call(entity),
          );
        }
        return Positioned(
          right: 10.0,
          child: widget.detailBuilder.call(entity),
        );
      },
    );
  }
}
