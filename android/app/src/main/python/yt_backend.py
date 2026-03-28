import yt_dlp
import os

def get_info(url):
    ydl_opts = {'quiet': True, 'no_warnings': True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        return ydl.extract_info(url, download=False)

def download_audio(url, output_dir, video_id):
    # We prioritize m4a because it's the most compatible with Android/iOS
    # fallback to any best audio if m4a isn't available
    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio', 
        'outtmpl': os.path.join(output_dir, f"{video_id}.%(ext)s"),
        'noplaylist': True,
        'quiet': True,
        'no_warnings': True,
    }
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        # 1. Download the file
        info = ydl.extract_info(url, download=True)
        
        # 2. Get the actual extension used (m4a, webm, etc.)
        actual_ext = info.get('ext', 'm4a')
        
        # 3. Construct the exact path where the file was saved
        final_path = os.path.join(output_dir, f"{video_id}.{actual_ext}")
        
        # Return this string back to Kotlin -> Flutter
        return final_path