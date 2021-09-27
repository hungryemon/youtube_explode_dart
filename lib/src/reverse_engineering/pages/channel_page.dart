import 'package:html/parser.dart' as parser;

import '../../exceptions/exceptions.dart';
import '../../extensions/helpers_extension.dart';
import '../../retry.dart';
import '../models/initial_data.dart';
import '../models/youtube_page.dart';
import '../youtube_http_client.dart';

///
class ChannelPage extends YoutubePage<_InitialData> {
  ///
  bool get isOk => root!.querySelector('meta[property="og:url"]') != null;

  ///
  String get channelUrl =>
      root!.querySelector('meta[property="og:url"]')?.attributes['content'] ??
      '';

  ///
  String get channelId => channelUrl.substringAfter('channel/');

  ///
  String get channelTitle =>
      root!.querySelector('meta[property="og:title"]')?.attributes['content'] ??
      '';

  ///
  String get channelLogoUrl =>
      root!.querySelector('meta[property="og:image"]')?.attributes['content'] ??
      '';

  int? get subscribersCount => initialData.subscribersCount;

  ///
  ChannelPage.parse(String raw)
      : super(parser.parse(raw), (root) => _InitialData(root));

  ///
  static Future<ChannelPage> get(YoutubeHttpClient httpClient, String id) {
    var url = 'https://www.youtube.com/channel/$id?hl=en';

    return retry(httpClient, () async {
      var raw = await httpClient.getString(url);
      var result = ChannelPage.parse(raw);

      if (!result.isOk) {
        throw TransientFailureException('Channel page is broken');
      }
      return result;
    });
  }

  ///
  static Future<ChannelPage> getByUsername(
      YoutubeHttpClient httpClient, String username) {
    var url = 'https://www.youtube.com/user/$username?hl=en';

    return retry(httpClient, () async {
      var raw = await httpClient.getString(url);
      var result = ChannelPage.parse(raw);

      if (!result.isOk) {
        throw TransientFailureException('Channel page is broken');
      }
      return result;
    });
  }
}

class _InitialData extends InitialData {
  static final RegExp _subCountExp = RegExp(r'(\d+(?:\.\d+)?)(K|M|\s)');

  _InitialData(JsonMap root) : super(root);

  int? get subscribersCount {
    final renderer = root.get('header')?.get('c4TabbedHeaderRenderer');
    if (renderer?['subscriberCountText'] == null) {
      return null;
    }
    final subText =
        renderer?.get('subscriberCountText')?.getT<String>('simpleText');
    if (subText == null) {
      return null;
    }
    final match = _subCountExp.firstMatch(subText);
    if (match == null) {
      return null;
    }
    if (match.groupCount != 2) {
      return null;
    }

    final count = double.tryParse(match.group(1) ?? '');
    if (count == null) {
      return null;
    }

    final multiplierText = match.group(2);
    if (multiplierText == null) {
      return null;
    }

    var multiplier = 1;
    if (multiplierText == 'K') {
      multiplier = 1000;
    } else if (multiplierText == 'M') {
      multiplier = 1000000;
    }

    return (count * multiplier).toInt();
  }
}
