import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MSupplyScreen extends StatefulWidget {
  const MSupplyScreen({super.key});

  @override
  State<MSupplyScreen> createState() => _MSupplyScreenState();
}

class _MSupplyScreenState extends State<MSupplyScreen> {
  List<List<dynamic>> _data = [];
  List<String> _headers = [];
  List<List<dynamic>> _filteredData = []; // Toutes les données filtrées
  List<List<dynamic>> _displayedData = []; // Données actuellement affichées (pagination)
  
  // Listes pour les filtres
  List<String> _regions = [];
  List<String> _districts = [];
  List<String> _filteredDistricts = [];

  // Indices des colonnes clés (dynamiques)
  int _nameIndex = -1;
  int _regionIndex = -1;
  int _districtIndex = -1;

  // Valeurs sélectionnées
  String? _selectedRegion;
  String? _selectedDistrict;

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _currentMax = 10;
  bool _isLoadingMore = false;

  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCsvData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _loadMoreData() {
    if (_displayedData.length < _filteredData.length && !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });

      Future.delayed(const Duration(milliseconds: 50), () {
        final nextMax = _currentMax + 20;
        final limit = nextMax > _filteredData.length ? _filteredData.length : nextMax;
        
        if (mounted) {
          setState(() {
            _displayedData.addAll(_filteredData.getRange(_currentMax, limit));
            _currentMax = limit;
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  Future<void> _loadCsvData() async {
    try {
      final input = await rootBundle.loadString('db/datas.csv');
      final fields = const CsvToListConverter(fieldDelimiter: ';').convert(input);

      if (fields.isNotEmpty) {
        final rawHeaders = fields.first.map((e) => e.toString().trim()).toList();
        final rawData = fields.skip(1).toList();

        // Configuration du nettoyage
        final columnsToRemove = [
          'Facility store 2', 
          'Facility store 3', 
          'Facility store 4', 
          'Store code'
        ];
        final renameMap = {'Facility Name': 'Nom du site'};

        // Identification des indices à garder
        final keptIndices = <int>[];
        final newHeaders = <String>[];

        for (int i = 0; i < rawHeaders.length; i++) {
          final header = rawHeaders[i];
          // Vérification insensible à la casse pour la suppression
          if (!columnsToRemove.any((r) => r.toLowerCase() == header.toLowerCase())) {
            keptIndices.add(i);
            // Renommage si nécessaire (insensible à la casse pour la clé)
            final renameKey = renameMap.keys.firstWhere(
              (k) => k.toLowerCase() == header.toLowerCase(), 
              orElse: () => header
            );
            newHeaders.add(renameMap[renameKey] ?? header);
          }
        }

        // Construction des nouvelles données filtrées
        final cleanedData = rawData.map((row) {
          return keptIndices.map((i) => i < row.length ? row[i] : '').toList();
        }).toList();

        // Repérage des nouveaux indices clés
        final nameIdx = newHeaders.indexOf('Nom du site');
        final finalNameIdx = nameIdx != -1 ? nameIdx : 0;

        final regionIdx = newHeaders.indexWhere((h) => h.toLowerCase() == 'region');
        final districtIdx = newHeaders.indexWhere((h) => h.toLowerCase() == 'district');

        // Extraction des listes uniques pour les filtres
        final regionsSet = <String>{};
        final districtsSet = <String>{};

        if (regionIdx != -1 && districtIdx != -1) {
          for (var row in cleanedData) {
            if (row.length > regionIdx) regionsSet.add(row[regionIdx].toString());
            if (row.length > districtIdx) districtsSet.add(row[districtIdx].toString());
          }
        }

        final regions = regionsSet.toList()..sort();
        final districts = districtsSet.toList()..sort();

        if (mounted) {
          setState(() {
            _headers = newHeaders;
            _data = cleanedData;
            _filteredData = cleanedData;
            _regions = regions;
            _districts = districts;
            _filteredDistricts = districts;
            
            _nameIndex = finalNameIdx;
            _regionIndex = regionIdx;
            _districtIndex = districtIdx;

            // Init pagination
            _currentMax = 10;
            _displayedData = _filteredData.take(_currentMax).toList();
            
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement du fichier : $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    
    final matches = _data.where((row) {
      // Utilisation des indices dynamiques
      final facilityName = (_nameIndex != -1 && row.length > _nameIndex) 
          ? row[_nameIndex].toString().toLowerCase() 
          : '';
      final matchesName = facilityName.contains(query);

      final region = (_regionIndex != -1 && row.length > _regionIndex) 
          ? row[_regionIndex].toString() 
          : '';
      final matchesRegion = _selectedRegion == null || region == _selectedRegion;

      final district = (_districtIndex != -1 && row.length > _districtIndex) 
          ? row[_districtIndex].toString() 
          : '';
      final matchesDistrict = _selectedDistrict == null || district == _selectedDistrict;

      return matchesName && matchesRegion && matchesDistrict;
    }).toList();

    setState(() {
      _filteredData = matches;
      _currentMax = 10;
      _displayedData = _filteredData.take(_currentMax).toList();
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onRegionChanged(String? newRegion) {
    setState(() {
      _selectedRegion = newRegion;
      _selectedDistrict = null;

      if (newRegion == null) {
        _filteredDistricts = _districts;
      } else {
        final districtsSet = <String>{};
        for (var row in _data) {
          if (_regionIndex != -1 && _districtIndex != -1 && row.length > _districtIndex && row.length > _regionIndex) {
            if (row[_regionIndex].toString() == newRegion) {
              districtsSet.add(row[_districtIndex].toString());
            }
          }
        }
        _filteredDistricts = districtsSet.toList()..sort();
      }
    });
    _filterData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
              : Column(
                  children: [
                    // Header Moderne
                    Container(
                      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'mSupply',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Détails Synchronisation Sites mSupply',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SvgPicture.network(
                                  'https://docs.msupply.foundation/icons/mSupplyTorso.svg',
                                  height: 40,
                                  width: 40,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  placeholderBuilder: (BuildContext context) => const SizedBox(width: 40, height: 40),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          // Barre de recherche intégrée
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Rechercher un site...',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => _filterData(),
                          ),
                        ],
                      ),
                    ),
                    
                    // Filtres
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedRegion,
                              decoration: const InputDecoration(
                                labelText: 'Région',
                                prefixIcon: Icon(Icons.map_outlined, size: 20),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Toutes'),
                                ),
                                ..._regions.map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r, overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: _onRegionChanged,
                              isExpanded: true,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedDistrict,
                              decoration: const InputDecoration(
                                labelText: 'District',
                                prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Tous'),
                                ),
                                ..._filteredDistricts.map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d, overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedDistrict = val;
                                });
                                _filterData();
                              },
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Liste des résultats
                    Expanded(
                      child: _displayedData.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun site trouvé',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemCount: _displayedData.length + (_displayedData.length < _filteredData.length ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _displayedData.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                
                                final row = _displayedData[index];
                                
                                final facilityName = (_nameIndex != -1 && row.length > _nameIndex) 
                                    ? row[_nameIndex].toString() 
                                    : 'Nom inconnu';
                                final region = (_regionIndex != -1 && row.length > _regionIndex) 
                                    ? row[_regionIndex].toString() 
                                    : '-';
                                final district = (_districtIndex != -1 && row.length > _districtIndex) 
                                    ? row[_districtIndex].toString() 
                                    : '-';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.08),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.store_mall_directory,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      title: Text(
                                        facilityName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '$region • $district',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Divider(height: 1),
                                              const SizedBox(height: 16),
                                              for (int i = 0; i < _headers.length; i++)
                                                if (i < row.length && i != _nameIndex && i != _regionIndex && i != _districtIndex)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 12.0),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        SizedBox(
                                                          width: 120,
                                                          child: Text(
                                                            _headers[i],
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.grey[500],
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            row[i].toString(),
                                                            style: const TextStyle(
                                                              color: Colors.black87,
                                                              fontWeight: FontWeight.w500,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
