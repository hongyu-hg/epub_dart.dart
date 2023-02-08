import 'dart:convert';
import 'dart:io';
import 'package:epub_dart/epub_package.dart';
import 'package:html/dom.dart';

import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart' as xml;

void main() async {
  // await testXml();
  await testPackageSingle();
  // test('adds one to input values', () {
  //   final calculator = Calculator();
  //   expect(calculator.addOne(2), 3);
  //   expect(calculator.addOne(-7), -6);
  //   expect(calculator.addOne(0), 1);
  //   expect(() => calculator.addOne(null), throwsNoSuchMethodError);
  // });
}

void testPackages() async {
  const files = [
    'A-Room-with-a-View-morrison.epub',
    'Beyond-Good-and-Evil-Galbraithcolor.epub',
    'epub31-v31-20170105.epub',
    'Metamorphosis-jackson.epub',
    'The-Prince-1397058899.epub',
    'The-Problems-of-Philosophy-LewisTheme.epub',
  ];

  final packages = files.map((fn) => EpubPackage(File('test/epubs/$fn'))).toList();

  final results = await Future.wait(packages.map((pkg) async {
    final start = DateTime.now();
    await pkg.load();
    final stop = DateTime.now();
    return {
      'start': start,
      'stop': stop,
      'package': pkg,
    };
  }));

  await Future.wait(results.map((h) async {
    final DateTime start = h['start'] as DateTime;
    final DateTime stop = h['stop'] as DateTime;
    final EpubPackage pkg = h['package'] as EpubPackage;
    final ts = stop.difference(start);
    print('[time: $ts]\t${pkg.filePath}');
    // print(jsonEncode(pkg));
    final coverAsset = pkg.metadata!.getCoverImageAsset();
    if (coverAsset != null) {
      final cover = pkg.getDocumentById(coverAsset.id)!;
      final bytes = (await cover.readAsBytes())!;
      print('${coverAsset.filename}: ${bytes.length}');
    }
    print('\n');
  }));
}

Future<void> testPackageSingle() async {
  print('started');
  final start = DateTime.now();
  final f = File('test/epubs/A-Room-with-a-View-morrison.epub');
  final package = EpubPackage(f);
  final succ = await package.load();
  final stop = DateTime.now();
  print('loaded: $succ');
  print("nav ${package.nav!.authors}");
  print("nav ${package.metadata}");
  var first;
  package.nav!.navMapList.forEach((element) {
    element.children!.forEach((element) {
      first ??= element.content;
      print("${element.label}");
    });
  });
  print(first);
  var t = (await package.getDocumentByPath(first)!.readText())!;
  var r = formatLineBreaks(t);
  // var text = html.parse(t);
  // // text.querySelectorAll(selector)
  // print("${text.documentElement.outerHtml}");
  // // print('$start - $stop');
  // // print(jsonEncode(package));
  // print('$start - $stop');
  print(r);
}

String formatLineBreaks(String htmlStr) {
  // print(htmlStr);
  //first - remove all the existing '\n' from HTML
  //they mean nothing in HTML, but break our logic
  htmlStr = htmlStr.replaceAll("\r", "").replaceAll("\n", " ");

  //now create an Html Agile Doc object
  var doc = html.parse(htmlStr);

  //remove comments, head, style and script tags
  for (var node in doc.querySelectorAll("comment,script,style,head")) {
    node.remove();
  }
  //block-elements - convert to line-breaks
  //you could add more tags here
  for (var node in doc.querySelectorAll("p,div,h1,h2,h3,h4,h5")) {
    //we add a "\n" ONLY if the node contains some plain text as "direct" child
    //meaning - text is not nested inside children, but only one-level deep

    //no "direct" text - NOT ADDDING the \n !!!!
    if (node.text == null || node.text.trim().isEmpty) continue;
    node.append(Text("\r\n"));
  }
  return doc.documentElement!.text;
}
//todo - you should probably add "&code;" processing, to decode all the &nbsp; and such

void testXml() async {
  final xmlStr = '''<?xml version="1.0" encoding="UTF-8" ?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/fb.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';
  final doc = xml.XmlDocument.parse(xmlStr);
  final root = doc.rootElement;
  final dom = root.findAllElements('rootfile').first;
  print(dom.getAttribute('full-path'));

  Directory current = Directory.current;
  print("Current folder: ${current}");

  final opf = File('test/epubs/jy/book.opf');
  final meta = EpubMeta.fromXml('test/epubs/jy/book.opf', opf.readAsStringSync());

  print(jsonEncode(meta));

  final ncxFile = File('test/epubs/jy/toc.ncx');
  final ncxXml = await ncxFile.readAsString();
  final ncxDom = html.parse(ncxXml);
  print(ncxDom.querySelector('head'));
  print(ncxDom.querySelector('docTitle'));
  print(ncxDom.querySelector('docAuthor'));
  final navMap = ncxDom.querySelector('navMap');
  print(navMap);
  print(ncxDom.querySelectorAll('navMap > navPoint'));

  final ncx = EpubNav.fromNcx(ncxFile.path, await ncxFile.readAsString());
  print(jsonEncode(ncx));
}
