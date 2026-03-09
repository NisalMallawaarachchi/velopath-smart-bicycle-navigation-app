const fs = require('fs');

const path = 'mobile_app/lib/screens/poi_screen.dart';
let content = fs.readFileSync(path, 'utf-8').replace(/\r\n/g, '\n');

if (!content.includes("import '../providers/theme_provider.dart';")) {
  content = content.replace("import '../config/api_config.dart';", "import '../config/api_config.dart';\nimport '../providers/theme_provider.dart';");
}

let startIndex = content.indexOf('  Widget _buildPoiCard(Map<String, dynamic> poi) {');
if (startIndex === -1) {
    console.error('Could not find _buildPoiCard function');
    process.exit(1);
}

const newCode = `  Widget _buildPoiCard(Map<String, dynamic> poi) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : ThemeProvider.primaryDarkBlue;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final name      = poi['name']     ?? "Unnamed";
    final amenity   = poi['amenity']  ?? "";
    final district  = poi['district'] ?? "";
    final tier      = (poi['tier']    ?? "new").toString();
    final rawScore  = poi['adjustedScore'] ?? poi['score'] ?? 0;
    final voteCount = _parseInt(poi['vote_count']);
    final isNew     = voteCount == 0;

    final starScore = _parseDouble(rawScore);
    final displayTier = isNew ? 'new' : tier;
    final color = _tierColor(displayTier);
    final icon  = _tierIcon(displayTier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white12) : Border.all(color: Colors.transparent),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: ThemeProvider.primaryDarkBlue.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          if (!isDark && tier == 'high')
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (myLocation == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enable "Use My Location" first.')),
              );
              return;
            }

            final updatedPoi = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => POIMapScreen(
                  startPoint: myLocation!,
                  selectedPoi: poi,
                  onLoyaltyUpdated: (points) {
                    setState(() => loyaltyPoints += points);
                  },
                ),
              ),
            );

            if (updatedPoi != null) {
              setState(() {
                final index = pois.indexWhere((p) => p['id'] == updatedPoi['id']);
                if (index != -1) {
                  final merged = Map<String, dynamic>.from(pois[index]);
                  merged['score']         = updatedPoi['score']         ?? merged['score'];
                  merged['vote_count']    = updatedPoi['vote_count']    ?? merged['vote_count'];
                  merged['adjustedScore'] = updatedPoi['adjustedScore'] ?? merged['adjustedScore'];

                  final newScore      = _parseDouble(merged['score']);
                  final newVoteCount  = _parseInt(merged['vote_count']);
                  merged['tier'] = _recalculateTier(newScore, newVoteCount);

                  pois[index] = merged;
                  applyFilters();
                }
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              isNew ? "NEW" : tier.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "\${amenity} • \${district}",
                              style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isNew ? ThemeProvider.accentCyan.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: isNew
                                ? const Text(
                                    "Be the first to rate",
                                    style: TextStyle(fontSize: 11, color: ThemeProvider.accentCyan, fontWeight: FontWeight.bold),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStarRow(starScore),
                                      const SizedBox(width: 6),
                                      Text(
                                        "\${starScore.toStringAsFixed(1)} (👥 \${voteCount})",
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade300, thickness: 1.5)),
        ],
      ),
    );
  }

  List<Widget> _buildSectionedList() {
    final ranked = filteredPois.where((p) => _parseInt(p['vote_count']) > 0).toList();
    final newPois = filteredPois.where((p) => _parseInt(p['vote_count']) == 0).toList();

    final items = <Widget>[];

    if (ranked.isNotEmpty) {
      items.add(_buildSectionHeader("Rated Places", Icons.star_rounded, Colors.orange));
      for (final poi in ranked) {
        items.add(_buildPoiCard(Map<String, dynamic>.from(poi)));
      }
    }

    if (newPois.isNotEmpty) {
      items.add(_buildSectionHeader("New Unrated Places", Icons.fiber_new_rounded, ThemeProvider.accentCyan));
      for (final poi in newPois) {
        items.add(_buildPoiCard(Map<String, dynamic>.from(poi)));
      }
    }

    return items;
  }

  int get _lowQualityTotal => pois.where((p) => (p['tier'] ?? 'new') == 'low').length;

  int get _newTotal => pois.where((p) => _parseInt(p['vote_count']) == 0).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Places to visit",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: ThemeProvider.primaryDarkBlue,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: ThemeProvider.accentCyan.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
          ],
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton.extended(
          backgroundColor: ThemeProvider.accentCyan,
          icon: const Icon(Icons.add_location_alt, color: ThemeProvider.primaryDarkBlue),
          label: const Text("Add POI", style: TextStyle(color: ThemeProvider.primaryDarkBlue, fontWeight: FontWeight.bold)),
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddPOIScreen()),
            );
            if (added == true) fetchPOIs();
          },
        ),
      ),
      body: Column(
        children: [
          // ── Minimalist Filter Section ──
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151E2E) : Colors.white,
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDistrict,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            dropdownColor: inputBgColor,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: [
                              "All", "Colombo", "Gampaha", "Kalutara", "Kandy",
                              "Matale", "Nuwara Eliya", "Galle", "Matara",
                              "Hambantota", "Jaffna", "Kilinochchi", "Mannar",
                              "Vavuniya", "Mullaitivu", "Batticaloa", "Ampara",
                              "Trincomalee", "Kurunegala", "Puttalam", "Anuradhapura",
                              "Polonnaruwa", "Badulla", "Monaragala", "Ratnapura",
                              "Kegalle",
                            ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => selectedDistrict = val);
                              fetchPOIs();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTier,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            dropdownColor: inputBgColor,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: [
                              DropdownMenuItem(value: "All", child: Text("All Tiers", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                              DropdownMenuItem(value: "new", child: Text("New", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue))),
                              DropdownMenuItem(value: "high", child: Text("High", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green))),
                              DropdownMenuItem(value: "medium", child: Text("Medium", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange))),
                              DropdownMenuItem(value: "low", child: Text("Low", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey))),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => selectedTier = val);
                              applyFilters();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search type (e.g. cafe, repair)",
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          onChanged: (val) {
                            searchQuery = val.toLowerCase();
                            applyFilters();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: ThemeProvider.primaryDarkBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.my_location, color: ThemeProvider.primaryDarkBlue),
                        onPressed: () => getMyLocation(silent: false),
                        tooltip: "Near Me",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_newTotal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: ThemeProvider.accentCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_new_rounded, size: 14, color: ThemeProvider.accentCyan),
                                const SizedBox(width: 4),
                                Text("\${_newTotal} New", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ThemeProvider.accentCyan)),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text("\${_lowQualityTotal} low hidden", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() => showLowQuality = !showLowQuality);
                        applyFilters();
                      },
                      child: Text(
                        showLowQuality ? "Hide Low" : "Show All",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThemeProvider.primaryDarkBlue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "\${filteredPois.length} place\${filteredPois.length == 1 ? '' : 's'} found",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: ThemeProvider.accentCyan))
                : filteredPois.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              "No POIs found.",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade500),
                            ),
                            if (!showLowQuality && _lowQualityTotal > 0) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() => showLowQuality = true);
                                  applyFilters();
                                },
                                child: const Text("Show low quality POIs too?", style: TextStyle(color: ThemeProvider.primaryDarkBlue, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: _buildSectionedList(),
                      ),
          ),
        ],
      ),
    );
  }
}
`;

content = content.substring(0, startIndex) + newCode;
fs.writeFileSync(path, content, 'utf-8');
console.log('Successfully replaced POI Screen UI.');
