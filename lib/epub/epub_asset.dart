part of epub_package;

final _pathRegEx = RegExp(r'[^\\/]');

class _Convert<T> {
  const _Convert();

  Map<String, T> map(Map<String, dynamic> json) => json.map((k, v) => MapEntry<String, T>(k, v));

  Iterable<T> list(List json) => json.map((v) => v as T);
}

const _as = _Convert<String>();

/// Joins file paths
String pathJoin(List<String?> paths) {
  final parts = paths.where((s) => s != null && s.isNotEmpty).toList();
  final lastIndex = parts.length - 1;
  for (var i = 0; i <= lastIndex; i += 1) {
    final part = parts[i]!;
    parts[i] = part.substring(
      i == 0 ? 0 : part.indexOf(_pathRegEx),
      i == lastIndex ? part.length : part.lastIndexOf(_pathRegEx) + 1,
    );
  }

  return p.normalize(parts.where((s) => s!.isNotEmpty).join('/')).replaceAll('\\', '/');
}

/// Represents a file in Zip package
class EpubFile {
  EpubFile(this.filename, this._offsetStart, this._offsetEnd, this._method);

  final String? filename;
  final int? _offsetStart;
  final int? _offsetEnd;
  final int? _method;

  bool get isCompressed => _method != 0;

  /// Reads file as `Stream<List<int>>`
  Stream<List<int>> toStream(File file) => ZipPackage.extract(
        file,
        start: _offsetStart,
        end: _offsetEnd,
        compressionMethod: _method,
      );

  /// Reads raw file as `Stream<List<int>>`
  Stream<List<int>> toRawStream(File file) => ZipPackage.raw(
        file,
        start: _offsetStart,
        end: _offsetEnd,
      );

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'offsetStart': _offsetStart,
        'offsetEnd': _offsetEnd,
        'compressedMethod': _method,
      };

  EpubFile.fromJson(Map<String, dynamic> json)
      : filename = json['filename'],
        _offsetStart = json['offsetStart'],
        _offsetEnd = json['offsetEnd'],
        _method = json['compressedMethod'];
}

/// Represents a XML tag, includes tag name, inner text and attributes
class XmlTag {
  /// Creates [XmlTag] with [name] and [text]
  XmlTag(this.name, this.text);

  /// Tag's name
  final String? name;

  /// Inner text
  final String? text;

  /// Attributes
  final attrs = <String, String>{};

  Map<String, dynamic> toJson() => {
        'name': name,
        'text': text,
        'attrs': attrs,
      };

  XmlTag.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        text = json['text'] {
    attrs.addAll(_as.map(json['attrs']));
  }
}

class _EpubXmlBase {
  xml.XmlElement _getXmlRoot(String xmlStr) => xml.XmlDocument.parse(xmlStr).rootElement;

  dom.Document _getHtmlRoot(String xmlStr) => html.parse(xmlStr);

  Iterable<xml.XmlElement> _childElements(xml.XmlElement parent) {
    // var r = parent.children.map((node) => node is xml.XmlElement ? node : null).where((n) => n != null) ;
    return parent.children.where((node) => node is xml.XmlElement).map((e) => e as xml.XmlElement);
  }
}

/// Internal record to represents an asset in EPub
class EpubAsset {
  EpubAsset._(this.id, this.href, this.mediaType, String? basePath) : filename = pathJoin([basePath, href]);

  final String? id;
  final String? href;
  final String? mediaType;
  final String? filename;

  final optional = <String, String>{};

  /// Helper method to populate relative item's path
  String relativePath(String path) => pathJoin([p.dirname(filename!), path]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'href': href,
        'filename': filename,
        'mediaType': mediaType,
        'optional': optional,
      };

  EpubAsset.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        href = json['href'],
        filename = json['filename'],
        mediaType = json['mediaType'] {
    optional.addAll(_as.map(json['optional']));
  }
}

/// External record to represents an asset in EPub
class EpubDocument {
  EpubDocument._({required this.package, this.id, required this.filename, this.asset})
      : dirname = p.dirname(filename),
        file = package.files[asset!.filename];

  /// Asset ID
  final String? id;

  /// Path of the asset in EPub
  final String dirname;

  /// Full path of the file in EPub
  final String filename;

  /// EPub package reference
  final EpubPackage package;

  /// [EpubAsset] reference
  final EpubAsset? asset;

  /// [EpubFile] reference
  final EpubFile? file;

  /// Returns if file is compressed
  bool get isCompressed => file!.isCompressed;

  /// Asset content type
  /// It prefers `asset.mediaType`
  /// If no [asset] assigned it will lookup by [filename]
  /// When [detectHeader] is set it will detect header
  Future<String?> mimeType({bool detectHeader = false}) async {
    if (asset != null) return asset!.mediaType;

    if (detectHeader) {
      final bytes = (await readAsBytes())!;
      return mime.lookupMimeType(filename, headerBytes: bytes);
    }

    return mime.lookupMimeType(filename);
  }

  /// Helper method to create instance from [package] and its [asset]
  static EpubDocument? fromAsset(EpubAsset? asset, EpubPackage package) => asset == null
      ? null
      : EpubDocument._(
          package: package,
          id: asset.id,
          filename: asset.filename!,
          asset: asset,
        );

  /// Reads content as `Stream`
  Future<Stream<List<int>>?> readStream() => package.fileStream(file);

  /// Reads content as `Stream`
  Future<Stream<List<int>>?> rawStream() => package.fileRawStream(file);

  /// Reads content as `List<int>`
  Future<List<int>?>? readAsBytes() => package.fileBytes(file);

  /// Reads content as `List<int>`
  Future<List<int>?>? rawAsBytes() => package.fileRawBytes(file);

  /// Reads content as UTF-8 String
  Future<String?> readText({Converter<List<int>, String>? decoder}) => package.readFileText(file, decoder: decoder);

  /// Returns relative [EpubDocument] to current document
  EpubDocument? getRelativeDoc(String relativePath) => package.getDocumentByPath(pathJoin([dirname, relativePath]));

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'package': package.file.path,
      };
}
