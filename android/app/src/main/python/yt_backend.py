import yt_dlp
import os

def download_audio(url, output_dir, video_id):
    """
    Highly optimized audio downloader for Giza.
    Uses the Android player client to bypass throttles and minimize extraction time.
    """
    # Define the final path to check existence before overhead
    final_path = os.path.join(output_dir, f"{video_id}.m4a")
    
    ydl_opts = {
        # Strictly prefer m4a for native Android playback compatibility
        'format': 'bestaudio[ext=m4a]/bestaudio/best',
        'outtmpl': os.path.join(output_dir, f"{video_id}.%(ext)s"),
        'noplaylist': True,
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'cachedir': False,
        'no_color': True,
        'extractor_args': {
            'youtube': {
                'player_client': ['android'],
                'skip': ['dash', 'hls'] # Skip manifest expansion to save time
            }
        },
        'buffersize': 1024 * 256, # 256KB buffer for smoother writes
        'http_chunk_size': 1024 * 1024, # 1MB chunks for faster downloads
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # extract_info with download=True is the most efficient single-pass method
            info = ydl.extract_info(url, download=True)
            return ydl.prepare_filename(info)
    except Exception as e:
        print(f"GIZA_PY_ERROR: {e}")
        return ""
