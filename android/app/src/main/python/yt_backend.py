import yt_dlp
import os

def download_audio(url, output_dir, video_id, quality='best'):
    """
    Highly optimized audio downloader for Giza with quality selection.
    Uses the Android player client to bypass throttles and minimize extraction time.
    
    Quality options:
    - 'best': Best available quality (default)
    - 'high': 320kbps or best available
    - 'medium': 192kbps or closest
    - 'low': 128kbps or closest
    """
    # Define the final path to check existence before overhead
    final_path = os.path.join(output_dir, f"{video_id}.m4a")
    
    # Map quality settings to format strings
    quality_formats = {
        'best': 'bestaudio[ext=m4a]/bestaudio/best',
        'high': 'bestaudio[abr>=256][ext=m4a]/bestaudio[abr>=256]/bestaudio[ext=m4a]/bestaudio/best',
        'medium': 'bestaudio[abr>=160][abr<=224][ext=m4a]/bestaudio[abr>=160][abr<=224]/bestaudio[ext=m4a]/bestaudio/best',
        'low': 'bestaudio[abr>=96][abr<=160][ext=m4a]/bestaudio[abr>=96][abr<=160]/bestaudio[ext=m4a]/bestaudio/best',
    }
    
    # Get format string based on quality, default to 'best'
    format_string = quality_formats.get(quality, quality_formats['best'])
    
    ydl_opts = {
        # Use quality-based format selection
        'format': format_string,
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
