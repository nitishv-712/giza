import yt_dlp
import os

def stream_audio(url, output_path):
    """
    Downloads a lightweight audio format for a quick start.
    Cleans up any existing file at output_path before starting.
    """
    print(f"PYTHON: Starting stream for {url} to {output_path}")

    # Clean up the previous stream file if it exists
    if os.path.exists(output_path):
        try:
            os.remove(output_path)
        except Exception as e:
            print(f"PYTHON: Error cleaning up: {e}")

    ydl_opts = {
        # Select lightweight m4a for fastest start and compatibility
        'format': 'ba*[ext=m4a]/ba*/worst',
        'outtmpl': output_path,
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'overwrites': True,
        'noplaylist': True,
        'cachedir': False,
        'socket_timeout': 15,
        'extractor_args': {'youtube': {'player_client': ['android']}},
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # download returns 0 for success
            result = ydl.download([url])
            print(f"PYTHON: Download finished with code {result}")
            return result == 0
    except Exception as e:
        print(f"PYTHON: yt-dlp Error: {e}")
        return False

def download_audio(url, output_dir, video_id):
    """Downloads the best audio format to a specific directory."""
    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio/best',
        'outtmpl': os.path.join(output_dir, f"{video_id}.%(ext)s"),
        'noplaylist': True,
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'cachedir': False,
        'extractor_args': {'youtube': {'player_client': ['android']}},
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            path = ydl.prepare_filename(info)
            return path
    except Exception as e:
        print(f"PYTHON: Download Error: {e}")
        return ""
