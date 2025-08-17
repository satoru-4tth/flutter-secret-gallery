import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class SecretGalleryPage extends StatefulWidget {
  const SecretGalleryPage({super.key});
  @override
  State<SecretGalleryPage> createState() => _SecretGalleryPageState();
}

class _SecretGalleryPageState extends State<SecretGalleryPage> {
  late Future<Directory> _vaultDirF;
  List<FileSystemEntity> _vaultFiles = [];

  @override
  void initState() {
    super.initState();
    _vaultDirF = _ensureVaultDir();
    _refreshVault();
  }

  Future<Directory> _ensureVaultDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _refreshVault() async {
    final dir = await _vaultDirF;
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() => _vaultFiles = files);
  }

  Future<void> _importFromSystem() async {
    // 1) 権限確認
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真へのアクセスが許可されていません')),
        );
      }
      return;
    }

    // 2) システムの選択UIを使って複数選択
    //   PhotoManager では「自前UIで選ばせる」パターンが基本。
    //   ここでは全アセットを一覧→簡易選択UIを出すより、
    //   まずは「最近の100件」などから選ばせる簡易版にします。
    final pathList = await PhotoManager.getAssetPathList(
      type: RequestType.common, // image + video
      onlyAll: true,
    );
    if (pathList.isEmpty) return;

    final recent = pathList.first; // "すべての写真"
    final assets = await recent.getAssetListPaged(page: 0, size: 200); // 最近200件

    // 簡易モーダルで選択
    final selected = await showModalBottomSheet<List<AssetEntity>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssetPickerSheet(assets: assets),
    );

    if (selected == null || selected.isEmpty) return;

    // 3) アプリ内にコピー
    final dir = await _vaultDirF;

    for (final asset in selected) {
      // バイト取得（元がHEICなどでもOK、元拡張子を推定）
      final file = await asset.file; // 原本ファイル（パスは読み取り専用のことも）
      final bytes = await asset.originBytes; // 失敗時は null もあり得る
      if (bytes == null) continue;

      final ext = _extFromAsset(asset, fallback: file?.path.split('.').last);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final name = 'vault_${ts}_${asset.id}.${ext}';
      final out = File('${dir.path}/$name');

      await out.writeAsBytes(bytes, flush: true);

      // 4) コピー成功後に削除確認
      final ok = await _confirmDeleteOriginal(asset);
      if (ok) {
        // iOS/Android とも OS ダイアログが出る場合あり
        try {
          await PhotoManager.editor.deleteWithIds([asset.id]);
        } catch (_) {
          // 一部端末は失敗することも
        }
      }
    }

    await _refreshVault();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取り込みが完了しました')),
      );
    }
  }

  String _extFromAsset(AssetEntity a, {String? fallback}) {
    // 画像/動画のUTI/タイプから拡張子推定
    // ざっくりマッピング（より厳密には AssetEntity の title を見る）
    final m = a.mimeType?.toLowerCase() ?? '';
    if (m.contains('jpeg')) return 'jpg';
    if (m.contains('png')) return 'png';
    if (m.contains('heic')) return 'heic';
    if (m.contains('webp')) return 'webp';
    if (m.contains('gif')) return 'gif';
    if (m.contains('mp4')) return 'mp4';
    if (m.contains('quicktime') || m.contains('mov')) return 'mov';
    return (fallback != null && fallback.isNotEmpty) ? fallback : 'bin';
  }

  Future<bool> _confirmDeleteOriginal(AssetEntity asset) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('元の写真/動画を削除しますか？'),
        content: Text('タイトル: ${asset.title ?? '(不明)'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('いいえ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除する')),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('秘密ギャラリー'),
        actions: [
          IconButton(
            onPressed: _importFromSystem,
            icon: const Icon(Icons.download),
            tooltip: '取り込み',
          ),
        ],
      ),
      body: _vaultFiles.isEmpty
          ? const Center(child: Text('まだ何も保存されていません'))
          : GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
        ),
        itemCount: _vaultFiles.length,
        itemBuilder: (ctx, i) {
          final f = _vaultFiles[i] as File;
          final isVideo = f.path.toLowerCase().endsWith('.mp4') || f.path.toLowerCase().endsWith('.mov');
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ViewerPage(file: f, isVideo: isVideo),
            )),
            child: Stack(
              children: [
                Positioned.fill(child: Image.file(f, fit: BoxFit.cover)),
                if (isVideo)
                  const Positioned(
                    right: 4, bottom: 4,
                    child: Icon(Icons.play_circle, size: 20, color: Colors.white),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssetPickerSheet extends StatefulWidget {
  const _AssetPickerSheet({required this.assets});
  final List<AssetEntity> assets;

  @override
  State<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<_AssetPickerSheet> {
  final _selected = <AssetEntity>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('取り込む写真/動画を選択', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6,
                ),
                itemCount: widget.assets.length,
                itemBuilder: (_, i) {
                  final a = widget.assets[i];
                  return FutureBuilder<Uint8List?>(
                    future: a.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                    builder: (_, snap) {
                      final th = snap.data;
                      final selected = _selected.contains(a);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(a);
                            } else {
                              _selected.add(a);
                            }
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: th != null
                                  ? Image.memory(th, fit: BoxFit.cover)
                                  : const ColoredBox(color: Colors.black12),
                            ),
                            if (selected)
                              const Positioned(
                                right: 4, top: 4,
                                child: Icon(Icons.check_circle, color: Colors.lightBlueAccent),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                      child: Text('取り込み (${_selected.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerPage extends StatelessWidget {
  const _ViewerPage({required this.file, required this.isVideo});
  final File file;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return Scaffold(
        appBar: AppBar(actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('削除しますか？'),
                  content: Text(file.path.split('/').last),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
                  ],
                ),
              ) ??
                  false;
              if (ok) {
                await file.delete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ]),
        body: Center(child: Image.file(file, fit: BoxFit.contain)),
      );
    }
    // 簡易版: 動画はOSビューアで開く方が安定（video_player を使ってもOK）
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('動画: ${file.path.split('/').last}\n（必要なら video_player 連携を追加）',
            textAlign: TextAlign.center),
      ),
    );
  }
}
