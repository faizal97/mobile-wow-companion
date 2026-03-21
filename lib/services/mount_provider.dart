import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/mount.dart';
import 'battlenet_api_service.dart';

/// Manages mount journal state: SimpleArmory catalogue + Blizzard collection.
///
/// Caching strategy (dual-layer, follows WowTokenProvider pattern):
///   - SimpleArmory journal: SharedPreferences, 7-day TTL (static game data).
///   - Account collection: SharedPreferences, 30min staleness / 2min rate limit.
///   - Mount details: in-memory map (lazy, per-mount, no TTL needed).
class MountProvider extends ChangeNotifier {
  final BattleNetApiService _apiService;
  final SharedPreferences _prefs;

  // Cache keys
  static const _journalCacheKey = 'mount_journal_data';
  static const _collectionCacheKey = 'mount_collection_data';
  static const _displaysCacheKey = 'mount_displays_data';
  // Cache version bumped when parsing logic changes
  static const _wagoCacheKey = 'mount_wago_data_v4';

  // Cache TTLs
  static const _journalTtl = Duration(days: 7);
  static const _displaysTtl = Duration(days: 7);
  static const _wagoTtl = Duration(days: 7);
  static const _collectionStaleness = Duration(minutes: 30);
  static const _collectionRateLimit = Duration(minutes: 2);

  // Data URLs
  static const _simpleArmoryUrl =
      'https://raw.githubusercontent.com/kevinclement/SimpleArmory/master/static/data/mounts.json';

  // Wago URLs proxied through Cloudflare Worker (CORS bypass)
  static String get _proxyBase => AppConfig.authProxyUrl;
  static String get _wagoUrl => '$_proxyBase/wago/Mount/csv';
  static String get _currencyUrl => '$_proxyBase/wago/CurrencyTypes/csv';
  static String get _journalEncounterUrl => '$_proxyBase/wago/JournalEncounter/csv';
  static String get _journalEncounterItemUrl => '$_proxyBase/wago/JournalEncounterItem/csv';
  static String get _journalInstanceUrl => '$_proxyBase/wago/JournalInstance/csv';

  // State
  List<Mount> _mounts = [];
  bool _isJournalLoading = false;
  bool _isCollectionLoading = false;
  String? _error;
  DateTime? _lastCollectionFetch;

  // Lazy mount detail cache (in-memory only)
  final Map<int, MountDetail> _detailCache = {};

  // Parsed expansion/category lists from SimpleArmory data
  List<String> _expansions = [];
  List<String> _categories = [];

  MountProvider(this._apiService, this._prefs);

  List<Mount> get mounts => _mounts;
  bool get isJournalLoading => _isJournalLoading;
  bool get isCollectionLoading => _isCollectionLoading;
  bool get isLoading => _isJournalLoading || _isCollectionLoading;
  String? get error => _error;
  List<String> get expansions => _expansions;
  List<String> get categories => _categories;
  int get collectedCount => _mounts.where((m) => m.isCollected).length;
  int get totalCount => _mounts.length;

  /// Returns mount count per source group.
  Map<MountSourceGroup, int> get sourceGroupCounts {
    final counts = <MountSourceGroup, int>{};
    for (final mount in _mounts) {
      final group = mount.sourceGroup;
      if (group != null) {
        counts[group] = (counts[group] ?? 0) + 1;
      }
    }
    return counts;
  }

  // Whether creature displays have been loaded (avoids re-fetching)
  bool _displaysLoaded = false;

  /// Loads journal, wago data, creature displays, and collection.
  Future<void> loadAll() async {
    await loadJournal();
    // Load wago, displays, and collection in parallel
    await Future.wait([
      loadWagoData(),
      loadCreatureDisplays(),
      loadCollection(),
    ]);
  }

  // ─── Journal (SimpleArmory) ──────────────────────────────────────────────

  /// Loads the mount journal from SimpleArmory (cache first, then network).
  Future<void> loadJournal() async {
    if (_mounts.isNotEmpty) return; // Already loaded

    _isJournalLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cache first
      var data = _getCachedJournal();

      if (data == null) {
        // Fetch from SimpleArmory
        data = await _fetchSimpleArmoryData();
        if (data != null) {
          _cacheJournal(data);
        }
      }

      if (data != null) {
        _parseSimpleArmoryData(data);
      } else if (_mounts.isEmpty) {
        _error = 'Failed to load mount data';
      }
    } catch (e) {
      if (_mounts.isEmpty) {
        _error = 'No connection — check your network';
      }
    }

    _isJournalLoading = false;
    notifyListeners();
  }

  /// Fetches SimpleArmory mounts.json from GitHub.
  Future<List<dynamic>?> _fetchSimpleArmoryData() async {
    try {
      final response = await http.get(Uri.parse(_simpleArmoryUrl));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses SimpleArmory JSON into Mount objects + expansion/category lists.
  void _parseSimpleArmoryData(List<dynamic> data) {
    final mounts = <Mount>[];
    final expansionList = <String>[];
    final categoryList = <String>[];

    // Known expansion names (in display order)
    const expansionNames = {
      'Midnight', 'The War Within', 'Dragonflight', 'Shadowlands',
      'Battle for Azeroth', 'Legion', 'Warlords of Draenor',
      'Mists of Pandaria', 'Cataclysm', 'Wrath of the Lich King',
      'The Burning Crusade', 'Classic',
    };

    // Skip meta-categories that don't contain actual mount listings
    const skipCategories = {'Mounts'};

    for (final cat in data) {
      final catName = cat['name'] as String? ?? '';
      if (skipCategories.contains(catName)) continue;

      final isExpansion = expansionNames.contains(catName);
      if (isExpansion) {
        expansionList.add(catName);
      } else {
        categoryList.add(catName);
      }

      final subcats = cat['subcats'] as List? ?? [];
      for (final sub in subcats) {
        final subName = sub['name'] as String? ?? '';
        final items = sub['items'] as List? ?? [];
        for (final item in items) {
          final id = item['ID'] as int?;
          if (id == null) continue;

          mounts.add(Mount(
            id: id,
            name: item['name'] as String? ?? 'Unknown Mount',
            icon: item['icon'] as String?,
            spellId: item['spellid'] as int?,
            itemId: item['itemId'] as int?,
            expansion: catName,
            sourceSubcategory: subName.isNotEmpty ? subName : null,
          ));
        }
      }
    }

    _mounts = mounts;
    _expansions = expansionList;
    _categories = categoryList;
  }

  List<dynamic>? _getCachedJournal() {
    final raw = _prefs.getString(_journalCacheKey);
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = wrapper['_cachedAt'] as int?;
      if (cachedAt == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > _journalTtl.inMilliseconds) {
        _prefs.remove(_journalCacheKey);
        return null;
      }

      return wrapper['data'] as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _cacheJournal(List<dynamic> data) {
    try {
      final wrapper = {
        'data': data,
        '_cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      _prefs.setString(_journalCacheKey, jsonEncode(wrapper));
    } catch (_) {
      // Journal data might be too large for SharedPreferences on some devices.
      // Silently fail — we'll re-fetch next time.
    }
  }

  // ─── Wago DB2 data (descriptions + acquisition info) ─────────────────────

  bool _wagoLoaded = false;

  /// Loads all Wago DB2 CSVs: Mount, PlayerCondition, CurrencyTypes, Journal tables.
  Future<void> loadWagoData() async {
    if (_wagoLoaded || _mounts.isEmpty) return;

    // Try cache first
    final cached = _getCachedWago();
    if (cached != null) {
      _applyWago(cached);
      _wagoLoaded = true;
      notifyListeners();
      return;
    }

    try {
      // Fetch all CSVs in parallel
      final responses = await Future.wait([
        http.get(Uri.parse(_wagoUrl)),              // 0: Mount
        http.get(Uri.parse(_playerConditionUrl)),    // 1: PlayerCondition
        http.get(Uri.parse(_currencyUrl)),           // 2: CurrencyTypes
        http.get(Uri.parse(_journalEncounterItemUrl)), // 3: JournalEncounterItem
        http.get(Uri.parse(_journalEncounterUrl)),   // 4: JournalEncounter
        http.get(Uri.parse(_journalInstanceUrl)),    // 5: JournalInstance
      ]);

      if (responses[0].statusCode != 200) return;

      // Parse supporting tables
      final conditions = responses[1].statusCode == 200
          ? _parsePlayerConditions(responses[1].body)
          : <String, String>{};

      final currencies = responses[2].statusCode == 200
          ? _parseCurrencyTypes(responses[2].body)
          : <String, String>{};

      // Parse journal tables for boss/instance enrichment
      Map<String, List<String>> itemToEncounters = {};
      Map<String, Map<String, String>> encounters = {};
      Map<String, String> instances = {};

      if (responses[3].statusCode == 200) {
        itemToEncounters = _parseEncounterItems(responses[3].body);
      }
      if (responses[4].statusCode == 200) {
        encounters = _parseEncounters(responses[4].body);
      }
      if (responses[5].statusCode == 200) {
        instances = _parseInstances(responses[5].body);
      }

      final parsed = _parseWagoCsv(
        responses[0].body,
        conditions,
        currencies,
        itemToEncounters,
        encounters,
        instances,
      );

      if (parsed.isNotEmpty) {
        _applyWago(parsed);
        _cacheWago(parsed);
        _wagoLoaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Non-critical — detail sheet will just show less info
    }
  }

  /// Parses PlayerCondition CSV into conditionID → failure description.
  Map<String, String> _parsePlayerConditions(String csv) {
    final result = <String, String>{};
    final lines = csv.split('\n');
    if (lines.length < 2) return result;

    for (var i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length < 3) continue;
      final id = fields[0];
      final desc = fields[2]; // Failure_description_lang
      if (desc.isNotEmpty) {
        result[id] = desc;
      }
    }
    return result;
  }

  /// Parses CurrencyTypes CSV into currencyID → name.
  Map<String, String> _parseCurrencyTypes(String csv) {
    final result = <String, String>{};
    final lines = csv.split('\n');
    if (lines.length < 2) return result;

    // Header: ID,Name_lang,...
    for (var i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length < 2) continue;
      final id = fields[0];
      final name = fields[1];
      if (name.isNotEmpty) {
        result[id] = name;
      }
    }
    return result;
  }

  /// Parses JournalEncounterItem CSV into itemID → list of encounterIDs.
  Map<String, List<String>> _parseEncounterItems(String csv) {
    final result = <String, List<String>>{};
    final lines = csv.split('\n');

    // Header: ID,JournalEncounterID,ItemID,...
    for (var i = 1; i < lines.length; i++) {
      final fields = lines[i].split(',');
      if (fields.length < 3) continue;
      final encId = fields[1];
      final itemId = fields[2];
      result.putIfAbsent(itemId, () => []).add(encId);
    }
    return result;
  }

  /// Parses JournalEncounter CSV into encounterID → {name, description, instanceID}.
  Map<String, Map<String, String>> _parseEncounters(String csv) {
    final result = <String, Map<String, String>>{};
    final lines = csv.split('\n');

    // Header: Name_lang,Description_lang,Map_0,Map_1,ID,JournalInstanceID,...
    for (var i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length < 6) continue;
      final id = fields[4];
      result[id] = {
        'name': fields[0],
        'desc': fields[1],
        'instId': fields[5],
      };
    }
    return result;
  }

  /// Parses JournalInstance CSV into instanceID → name.
  Map<String, String> _parseInstances(String csv) {
    final result = <String, String>{};
    final lines = csv.split('\n');

    // Header: ID,Name_lang,...
    for (var i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length < 2) continue;
      result[fields[0]] = fields[1];
    }
    return result;
  }

  /// Parses Wago Mount CSV with all enrichment data.
  Map<int, Map<String, dynamic>> _parseWagoCsv(
    String csv,
    Map<String, String> conditions,
    Map<String, String> currencies,
    Map<String, List<String>> itemToEncounters,
    Map<String, Map<String, String>> encounters,
    Map<String, String> instances,
  ) {
    final result = <int, Map<String, dynamic>>{};
    final lines = csv.split('\n');
    if (lines.isEmpty) return result;

    // Build SimpleArmory itemId → mountId lookup for journal cross-reference
    final mountItemIds = <int, int>{}; // itemId → mountId
    for (final mount in _mounts) {
      if (mount.itemId != null) {
        mountItemIds[mount.itemId!] = mount.id;
      }
    }

    // Columns: Name,SourceText,Description,ID,MountTypeID,Flags,SourceTypeEnum,
    //          SourceSpellID,PlayerConditionID,...
    for (var i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length < 9) continue;

      final id = int.tryParse(fields[3]);
      if (id == null) continue;

      final sourceText = _stripWowMarkup(fields[1], currencies);
      final description = fields[2];
      final mountTypeId = int.tryParse(fields[4]) ?? 0;
      final conditionId = fields[8];

      final requirement = conditions[conditionId];

      final entry = <String, dynamic>{
        if (sourceText.isNotEmpty) 'st': sourceText,
        if (description.isNotEmpty) 'd': description,
        'mt': mountTypeId,
      };
      if (requirement != null && requirement.isNotEmpty) {
        entry['req'] = requirement;
      }

      result[id] = entry;
    }

    // Enrich with journal data: cross-reference mount itemIds with loot tables
    for (final mount in _mounts) {
      if (mount.itemId == null) continue;
      final entry = result[mount.id];
      if (entry == null) continue;

      final encIds = itemToEncounters[mount.itemId.toString()];
      if (encIds == null || encIds.isEmpty) continue;

      // Use first encounter match
      final enc = encounters[encIds.first];
      if (enc == null) continue;

      entry['bn'] = enc['name'] ?? '';  // boss name
      final bossDesc = enc['desc'] ?? '';
      if (bossDesc.isNotEmpty) entry['bd'] = bossDesc; // boss description
      final instName = instances[enc['instId'] ?? ''];
      if (instName != null) entry['in'] = instName; // instance name
    }

    return result;
  }

  /// Simple CSV line parser that handles quoted fields with commas.
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var inQuotes = false;
    var current = StringBuffer();

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        fields.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    fields.add(current.toString());
    return fields;
  }

  // Currency icon path → display name
  static const _currencyIcons = <String, String>{
    'ui-goldicon': 'Gold',
    'ui-silvericon': 'Silver',
    'ui-coppericon': 'Copper',
    'pvpcurrency-honor-alliance': 'Honor',
    'pvpcurrency-honor-horde': 'Honor',
    'ability_paladin_artofwar': "Champion's Seal",
    'ability_pvp_gladiatormedallion': 'Mark of Honor',
    'achievement_bg_kill_on_mount': 'Vicious Saddle',
    'inv_misc_ticket_darkmoon_01': 'Darkmoon Prize Ticket',
    'achievement_noblegarden_chocolate_egg': 'Noblegarden Chocolate',
    'inv_valentinescard01': 'Love Token',
    'inv_misc_curiouscoin': 'Curious Coin',
    'inv_faction_warresources': 'War Resources',
    'inv_alliancewareffort': 'Service Medal',
    'inv_hordewareffort': 'Service Medal',
    'inv_apexis_draenor': 'Apexis Crystal',
    'inv_misc_stormlordsfavor': 'Timewarped Badge',
    'spell_animabastion_orb': 'Anima',
    'inv_stygia': 'Stygia',
    'pvecurrency-justice': 'Timeless Coin',
    'timelesscoin-bloody': 'Bloody Coin',
    'timelesscoin_yellow': 'Paracausal Flake',
    'inv_misc_azsharacoin': "Seafarer's Dubloon",
    'inv_misc_coin_19': "Nat's Lucky Coin",
    'inv_misc_coin_08': 'Kej',
    'inv_misc_coin_12': 'Mrrgl',
    'achievement_zone_tolbarad': 'Tol Barad Commendation',
    'inv_misc_rune_08': 'Halaa Battle Token',
    'inv_misc_rune_09': 'Halaa Research Token',
    'spell_azerite_essence14': 'Resonance Crystals',
    'spell_azerite_essence_15': 'Undercoin',
    'inv_7_0raid_trinket_05a': 'Dragon Isles Supplies',
    'inv_misc_enchantedpearlf': 'Prismatic Manapearl',
    'inv_misc_monsterscales_18': 'Corrupted Memento',
    'inv_misc_paperbundle04a': 'Cataloged Research',
    'inv_misc_powder_thorium': 'Elemental Overflow',
    'inv_misc_blacksaberonfang': 'Blackfang Claw',
    'inv_misc_trailofflowers': 'Dreamseeds',
    'inv_legion_faction_dreamweavers': 'Bloom',
    'inv_misc_phoenixegg': 'Celestial Coin',
    'inv_misc_food_111_icefinfillet': 'Benthic Clam',
    'inv_elemental_primal_water': 'Drowned Mana',
    'inv_misc_dust_05': 'Lamplighter Supply Satchel',
    'inv_engineering_90_toolbox_orange': 'Gadgetzan Gazette',
    'inv_stone_weightstone_08': 'Barter Boulder',
    'inv_ability_honey_orb': 'Bee Wax',
    'inv_112_raidtrinkets_voidprism': 'Memory of Nullification',
    'inv_10_tailoring_silkrare_color3': 'Silk Thread',
    'archaeology_5_0_mogucoin': 'Coalescing Visions',
    'inv_10_gathering_bioluminescentspores_large': 'Residual Memories',
    'inv_belt_armor_bloodelf_d_01': 'Unraveling Thread',
    'inv_misc_elvencoins': 'Restored Coffer Key',
    'creatureportrait_twilightshammer_lava_magicball': 'Flightstones',
    'inv_enchant_duststrange': 'Whelpling Crest',
    'inv_icon_feather05d': 'Dragon Whelpling Crest',
    'inv_feather_11': 'Whelpling Crest',
    'inv_misc_token_pvp01': 'PvP Token',
  };

  /// Resolves a texture icon path to a currency name.
  static String _resolveCurrency(String texturePath) {
    // Extract filename without extension, case-insensitive
    final parts = texturePath.replaceAll('\\', '/').split('/');
    final filename = parts.last.replaceAll(RegExp(r'\.blp.*', caseSensitive: false), '').toLowerCase().trim();
    return _currencyIcons[filename] ?? filename;
  }

  /// Strips WoW rich text markup from SourceText, resolving currencies.
  static String _stripWowMarkup(String text, [Map<String, String> currencies = const {}]) {
    if (text.isEmpty) return '';
    var s = text;
    // Remove color codes
    s = s.replaceAll(RegExp(r'\|c[0-9A-Fa-f]{8}'), '');
    s = s.replaceAll('|r', '');

    // Resolve |Hcurrency:ID|h...|h → extract currency ID, look up name
    // Also handle |Hitem:ID|h...|h
    // We process these BEFORE textures so we can use the currency ID
    s = s.replaceAllMapped(
      RegExp(r'\|Hcurrency:(\d+)\|h(.*?)\|h'),
      (m) {
        final currencyId = m.group(1) ?? '';
        final currencyName = currencies[currencyId];
        if (currencyName != null) return ' $currencyName';
        // Fallback: strip the hyperlink, keep inner content (texture will be resolved next)
        return m.group(2) ?? '';
      },
    );
    // Remove item hyperlinks (keep inner content for texture resolution)
    s = s.replaceAllMapped(
      RegExp(r'\|Hitem:\d+\|h(.*?)\|h'),
      (m) => m.group(1) ?? '',
    );
    // Remove any remaining hyperlinks
    s = s.replaceAll(RegExp(r'\|H[^|]*\|h'), '');
    s = s.replaceAll('|h', '');

    // Replace texture/icon refs with currency names (fallback for non-hyperlinked icons)
    s = s.replaceAllMapped(RegExp(r'\|T([^|]*)\|t'), (m) {
      final currency = _resolveCurrency(m.group(1) ?? '');
      return ' $currency';
    });

    // Convert WoW newlines
    s = s.replaceAll('|n', '\n');
    return s.trim();
  }

  /// Parses "Key: Value\nKey: Value" source text into structured fields.
  static MountAcquisition _parseAcquisition(String sourceText) {
    final fields = <String, String>{};
    for (final line in sourceText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx > 0 && colonIdx < trimmed.length - 1) {
        final key = trimmed.substring(0, colonIdx).trim();
        final value = trimmed.substring(colonIdx + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          fields[key] = value;
        }
      } else {
        // Single value without key (e.g. "Trading Post", "Legacy")
        fields['Source'] = trimmed;
      }
    }
    return MountAcquisition(fields);
  }

  void _applyWago(Map<int, Map<String, dynamic>> data) {
    for (final mount in _mounts) {
      final entry = data[mount.id];
      if (entry == null) continue;

      final sourceText = entry['st'] as String?;
      if (sourceText != null && sourceText.isNotEmpty) {
        mount.acquisition = _parseAcquisition(sourceText);
      }

      final desc = entry['d'] as String?;
      if (desc != null && desc.isNotEmpty) {
        mount.description = desc;
      }

      final mtId = entry['mt'] as int?;
      mount.mountType = MountType.fromTypeId(mtId);

      final req = entry['req'] as String?;
      if (req != null && req.isNotEmpty) {
        mount.requirement = req;
      }

      // Journal enrichment
      final bossName = entry['bn'] as String?;
      if (bossName != null && bossName.isNotEmpty) {
        mount.bossName = bossName;
      }
      final bossDesc = entry['bd'] as String?;
      if (bossDesc != null && bossDesc.isNotEmpty) {
        mount.bossDescription = bossDesc;
      }
      final instName = entry['in'] as String?;
      if (instName != null && instName.isNotEmpty) {
        mount.instanceName = instName;
      }
    }
  }

  Map<int, Map<String, dynamic>>? _getCachedWago() {
    final raw = _prefs.getString(_wagoCacheKey);
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = wrapper['_cachedAt'] as int?;
      if (cachedAt == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > _wagoTtl.inMilliseconds) {
        _prefs.remove(_wagoCacheKey);
        return null;
      }

      final entries = wrapper['data'] as Map<String, dynamic>? ?? {};
      return entries.map((k, v) =>
          MapEntry(int.parse(k), Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return null;
    }
  }

  void _cacheWago(Map<int, Map<String, dynamic>> data) {
    try {
      final wrapper = {
        'data': data.map((k, v) => MapEntry(k.toString(), v)),
        '_cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      _prefs.setString(_wagoCacheKey, jsonEncode(wrapper));
    } catch (_) {
      // Silently fail — ~800KB, might be too large on some devices
    }
  }

  // ─── Creature displays (Wago MountXDisplay CSV) ──────────────────────────

  static String get _mountXDisplayUrl => '$_proxyBase/wago/MountXDisplay/csv';
  static String get _playerConditionUrl => '$_proxyBase/wago/PlayerCondition/csv';

  /// Loads creature display IDs from Wago MountXDisplay CSV (single download).
  /// Replaces 16 paginated Blizzard search API calls.
  Future<void> loadCreatureDisplays() async {
    if (_displaysLoaded || _mounts.isEmpty) return;

    // Try cache first
    final cached = _getCachedDisplays();
    if (cached != null) {
      _applyDisplays(cached);
      _displaysLoaded = true;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(Uri.parse(_mountXDisplayUrl));
      if (response.statusCode == 200) {
        final displays = _parseMountXDisplayCsv(response.body);
        if (displays.isNotEmpty) {
          _applyDisplays(displays);
          _cacheDisplays(displays);
          _displaysLoaded = true;
          notifyListeners();
        }
      }
    } catch (_) {
      // Non-critical — grid will fall back to spell icons
    }
  }

  /// Parses MountXDisplay CSV into mount ID → first creature display ID.
  Map<int, int> _parseMountXDisplayCsv(String csv) {
    final result = <int, int>{};
    final lines = csv.split('\n');
    for (var i = 1; i < lines.length; i++) {
      final fields = lines[i].split(',');
      if (fields.length < 5) continue;
      final displayId = int.tryParse(fields[1]);
      final mountId = int.tryParse(fields[4]);
      if (displayId == null || mountId == null) continue;
      // Keep first display per mount (primary appearance)
      result.putIfAbsent(mountId, () => displayId);
    }
    return result;
  }

  void _applyDisplays(Map<int, int> displays) {
    for (final mount in _mounts) {
      final displayId = displays[mount.id];
      if (displayId != null) {
        mount.creatureDisplayId = displayId;
      }
    }
  }

  Map<int, int>? _getCachedDisplays() {
    final raw = _prefs.getString(_displaysCacheKey);
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = wrapper['_cachedAt'] as int?;
      if (cachedAt == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > _displaysTtl.inMilliseconds) {
        _prefs.remove(_displaysCacheKey);
        return null;
      }

      final entries = wrapper['displays'] as Map<String, dynamic>? ?? {};
      return entries.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {
      return null;
    }
  }

  void _cacheDisplays(Map<int, int> displays) {
    try {
      final wrapper = {
        'displays': displays.map((k, v) => MapEntry(k.toString(), v)),
        '_cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      _prefs.setString(_displaysCacheKey, jsonEncode(wrapper));
    } catch (_) {
      // Silently fail — grid will fall back to spell icons
    }
  }

  // ─── Collection (Blizzard API) ───────────────────────────────────────────

  /// Loads account mount collection, respecting staleness cache.
  Future<void> loadCollection() async {
    // Skip if within staleness window
    if (_lastCollectionFetch != null) {
      final elapsed = DateTime.now().difference(_lastCollectionFetch!);
      if (elapsed < _collectionStaleness) return;
    }

    // Try cached collection first
    final cached = _getCachedCollection();
    if (cached != null) {
      _applyCollection(cached);
      return;
    }

    await _fetchCollection();
  }

  /// Refreshes all data on pull-to-refresh.
  /// Retries wago/displays if they haven't loaded, refreshes collection.
  Future<void> refresh() async {
    final futures = <Future>[];

    // Retry wago if it hasn't loaded, or if mounts lack descriptions
    if (!_wagoLoaded ||
        (_mounts.isNotEmpty && _mounts.first.description == null)) {
      _wagoLoaded = false;
      _prefs.remove(_wagoCacheKey);
      futures.add(loadWagoData());
    }

    // Retry displays if they haven't loaded
    if (!_displaysLoaded) {
      futures.add(loadCreatureDisplays());
    }

    // Refresh collection (bypasses staleness, respects rate limit)
    if (_lastCollectionFetch == null ||
        DateTime.now().difference(_lastCollectionFetch!) >= _collectionRateLimit) {
      futures.add(_fetchCollection());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _fetchCollection() async {
    _isCollectionLoading = true;
    notifyListeners();

    try {
      final collection = await _apiService.getAccountMountCollection();
      if (collection != null) {
        _applyCollection(collection);
        _cacheCollection(collection);
        _lastCollectionFetch = DateTime.now();
      }
    } catch (_) {
      // Keep existing collection state — offline mode
    }

    _isCollectionLoading = false;
    notifyListeners();
  }

  void _applyCollection(Map<int, ({bool isCollected, bool isFavorite})> collection) {
    for (final mount in _mounts) {
      final entry = collection[mount.id];
      if (entry != null) {
        mount.isCollected = entry.isCollected;
        mount.isFavorite = entry.isFavorite;
      } else {
        mount.isCollected = false;
        mount.isFavorite = false;
      }
    }
    // Also update _lastCollectionFetch from cache timestamp if loading from cache
    notifyListeners();
  }

  Map<int, ({bool isCollected, bool isFavorite})>? _getCachedCollection() {
    final raw = _prefs.getString(_collectionCacheKey);
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = wrapper['_cachedAt'] as int?;
      if (cachedAt == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > _collectionStaleness.inMilliseconds) {
        // Stale but don't delete — still usable as fallback
        // Return null so we try network, but keep cache for offline
      }

      final entries = wrapper['mounts'] as Map<String, dynamic>? ?? {};
      final result = <int, ({bool isCollected, bool isFavorite})>{};

      for (final entry in entries.entries) {
        final id = int.tryParse(entry.key);
        if (id == null) continue;
        final data = entry.value as Map<String, dynamic>;
        result[id] = (
          isCollected: data['c'] == true,
          isFavorite: data['f'] == true,
        );
      }

      // Update the last fetch time from cache
      _lastCollectionFetch = DateTime.fromMillisecondsSinceEpoch(cachedAt);

      // Only return if within staleness window
      if (age <= _collectionStaleness.inMilliseconds) {
        return result;
      }

      // Stale: apply as fallback but return null so network fetch happens
      _applyCollection(result);
      return null;
    } catch (_) {
      return null;
    }
  }

  void _cacheCollection(Map<int, ({bool isCollected, bool isFavorite})> collection) {
    final entries = <String, dynamic>{};
    for (final entry in collection.entries) {
      entries[entry.key.toString()] = {
        'c': entry.value.isCollected,
        'f': entry.value.isFavorite,
      };
    }
    final wrapper = {
      'mounts': entries,
      '_cachedAt': DateTime.now().millisecondsSinceEpoch,
    };
    _prefs.setString(_collectionCacheKey, jsonEncode(wrapper));
  }

  // ─── Mount detail (lazy, in-memory) ──────────────────────────────────────

  /// Gets cached mount detail, or null if not yet fetched.
  MountDetail? getCachedDetail(int mountId) => _detailCache[mountId];

  /// Fetches mount detail from Blizzard API. Returns cached if available.
  Future<MountDetail?> fetchMountDetail(int mountId) async {
    final cached = _detailCache[mountId];
    if (cached != null) return cached;

    final detail = await _apiService.getMountDetail(mountId);
    if (detail != null) {
      _detailCache[mountId] = detail;
    }
    return detail;
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  /// Clears collection data (on region switch or logout).
  void clearCollection() {
    for (final mount in _mounts) {
      mount.isCollected = false;
      mount.isFavorite = false;
    }
    _lastCollectionFetch = null;
    _prefs.remove(_collectionCacheKey);
    notifyListeners();
  }

  /// Clears all mount data (on logout).
  void clearAll() {
    _mounts = [];
    _detailCache.clear();
    _expansions = [];
    _categories = [];
    _displaysLoaded = false;
    _wagoLoaded = false;
    _lastCollectionFetch = null;
    _error = null;
    _prefs.remove(_journalCacheKey);
    _prefs.remove(_collectionCacheKey);
    _prefs.remove(_displaysCacheKey);
    _prefs.remove(_wagoCacheKey);
    // Clean up old cache keys from previous versions
    _prefs.remove('mount_wago_data');
    _prefs.remove('mount_wago_data_v2');
    _prefs.remove('mount_wago_data_v3');
    notifyListeners();
  }
}
