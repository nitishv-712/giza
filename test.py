import time
import yt_dlp
import requests # You might need to run: pip install requests

def get_direct_url(url):
    ydl_opts = {
        # Using the fast/lower quality option for maximum speed
        'format': '139/worstaudio[ext=m4a]/bestaudio[ext=m4a]/best',
        'quiet': True,
        'no_warnings': True,
        'skip_download': True,
        'nocheckcertificate': True,
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'web']
            }
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)

            if 'url' in info:
                return info['url']
            elif 'requested_formats' in info:
                return info['requested_formats'][0]['url']
            else:
                return ""

    except Exception as e:
        print(f"PYTHON ERR in get_direct_url: {e}")
        return ""


def run_latency_test(test_url, iterations=3):
    print(f"Testing latency for: {test_url}")
    print("-" * 50)

    total_overall_time = 0

    for i in range(1, iterations + 1):
        print(f"Run {i}/{iterations}...")

        # 1. Start timer for Metadata Extraction
        t0 = time.time()
        direct_url = get_direct_url(test_url)
        t1 = time.time()

        url_latency = t1 - t0

        if not direct_url:
            print("  [-] Failed to extract URL.\n")
            continue

        print(f"  [+] URL extracted in:      {url_latency:.3f} seconds")

        # 2. Start timer for the First Chunk of Data (TTFB)
        try:
            t2 = time.time()

            # Pretend to be a standard mobile browser so YouTube doesn't block the stream
            headers = {
                'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36'
            }

            # stream=True ensures we don't wait for the whole song to download
            with requests.get(direct_url, stream=True, headers=headers, timeout=10) as response:
                response.raise_for_status() # Check if YouTube blocked it (e.g., 403 Forbidden)

                # Grab the very first 1024 bytes (1 KB) of audio
                chunk = next(response.iter_content(chunk_size=1024))
                t3 = time.time()

                first_chunk_latency = t3 - t2
                total_run_latency = t3 - t0
                total_overall_time += total_run_latency

                print(f"  [+] First audio chunk in:  {first_chunk_latency:.3f} seconds")
                print(f"  ⏱️  Total App Wait Time:   {total_run_latency:.3f} seconds\n")

        except Exception as e:
            print(f"  [-] Failed to fetch stream chunk: {e}\n")

        # Be polite to YouTube servers
        time.sleep(1)

    if iterations > 0:
        avg_time = total_overall_time / iterations
        print("-" * 50)
        print(f"Average Total Latency (Click to Music): {avg_time:.3f} seconds")


if __name__ == "__main__":
    # "Me at the zoo" - The first YouTube video ever.
    sample_youtube_url = "https://www.youtube.com/watch?v=jNQXAC9IVRw"

    # Run the test
    run_latency_test(sample_youtube_url, iterations=3)