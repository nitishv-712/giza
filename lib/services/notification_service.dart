import 'package:audio_service/audio_service.dart';
import '../models/song.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  AudioHandler? _audioHandler;

  Future<void> init() async {
    _audioHandler = await AudioService.init(
      builder: () => GizaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.giza.audio',
        androidNotificationChannelName: 'Giza Music',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  Future<void> updateNotification({
    required Song song,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
  }) async {
    if (_audioHandler == null) return;

    final mediaItem = MediaItem(
      id: song.youtubeVideoId ?? song.title,
      title: song.title,
      artist: song.artist,
      artUri: Uri.parse(song.artworkUrl),
      duration: duration,
    );

    final handler = _audioHandler as GizaAudioHandler;
    handler.updateMediaItem(mediaItem);
    handler.updatePlaybackState(
      playing: isPlaying,
      position: position,
      duration: duration,
    );
  }

  Future<void> clearNotification() async {
    await _audioHandler?.stop();
  }

  void setHandlers({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function(Duration) onSeek,
  }) {
    if (_audioHandler is GizaAudioHandler) {
      final handler = _audioHandler as GizaAudioHandler;
      handler.onPlayCallback = onPlay;
      handler.onPauseCallback = onPause;
      handler.onNextCallback = onNext;
      handler.onPreviousCallback = onPrevious;
      handler.onSeekCallback = onSeek;
    }
  }
}

class GizaAudioHandler extends BaseAudioHandler {
  Function()? onPlayCallback;
  Function()? onPauseCallback;
  Function()? onNextCallback;
  Function()? onPreviousCallback;
  Function(Duration)? onSeekCallback;

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        bufferedPosition: duration,
        speed: 1.0,
      ),
    );
  }

  @override
  Future<void> play() async => onPlayCallback?.call();

  @override
  Future<void> pause() async => onPauseCallback?.call();

  @override
  Future<void> skipToNext() async => onNextCallback?.call();

  @override
  Future<void> skipToPrevious() async => onPreviousCallback?.call();

  @override
  Future<void> seek(Duration position) async => onSeekCallback?.call(position);

  @override
  Future<void> stop() async {
    await super.stop();
    onPauseCallback?.call();
  }
}
