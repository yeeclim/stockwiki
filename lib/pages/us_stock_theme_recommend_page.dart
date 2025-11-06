import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/fmp_service.dart';
import 'us_stock_detail_page.dart';

class UsStockThemeRecommendPage extends StatefulWidget {
  const UsStockThemeRecommendPage({super.key});

  @override
  State<UsStockThemeRecommendPage> createState() =>
      _UsStockThemeRecommendPageState();
}

class _UsStockThemeRecommendPageState extends State<UsStockThemeRecommendPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _sectors = [];
  Map<String, List<Stock>> _sectorStocks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sectors = FMPService.getAvailableSectors();
    _tabController = TabController(length: _sectors.length, vsync: this);
    _loadAllSectors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSectors() async {
    setState(() => _isLoading = true);

    try {
      for (String sector in _sectors) {
        final stocks = await FMPService.fetchStocksBySector(sector, limit: 10);
        setState(() {
          _sectorStocks[sector] = stocks;
        });
      }
    } catch (e) {
      print('Sector별 주식 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSector(String sector) async {
    if (_sectorStocks.containsKey(sector) && _sectorStocks[sector]!.isNotEmpty) {
      return; // 이미 로드됨
    }

    setState(() => _isLoading = true);
    try {
      final stocks = await FMPService.fetchStocksBySector(sector, limit: 10);
      setState(() {
        _sectorStocks[sector] = stocks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getSectorIcon(String sector) {
    switch (sector) {
      case 'Technology':
        return '💻';
      case 'Finance':
        return '💰';
      case 'Healthcare':
        return '🏥';
      case 'Consumer':
        return '🛒';
      case 'Energy':
        return '⚡';
      case 'Industrial':
        return '🏭';
      default:
        return '📊';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('📊 Sector별 추천 종목', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllSectors,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          indicatorColor: Colors.blue,
          tabs: _sectors.map((sector) {
            return Tab(
              text: '$_getSectorIcon(sector) $sector',
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _sectors.map((sector) {
          return _buildSectorContent(sector);
        }).toList(),
      ),
    );
  }

  Widget _buildSectorContent(String sector) {
    if (_isLoading && !_sectorStocks.containsKey(sector)) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    final stocks = _sectorStocks[sector] ?? [];

    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text(
              '해당 Sector의 주식을 찾을 수 없습니다',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadSector(sector),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSector(sector),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: stocks.length,
        itemBuilder: (context, index) {
          final stock = stocks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.grey[800],
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  stock.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      stock.symbol,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    if (stock.price != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '\$${stock.price!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: stock.changePercent != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stock.changePercent! >= 0 ? '+' : ''}${stock.changePercent!.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: stock.changePercent! >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            stock.changePercent! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: stock.changePercent! >= 0
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                        ],
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UsStockDetailPage(stock: stock),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

