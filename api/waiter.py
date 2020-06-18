import socket
from time import sleep
import subprocess
from multiprocessing import cpu_count

so = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
while True:
    try:
        so.connect(('db', 5432))
        so.close()
        break
    except socket.error:
        sleep(1)
# subprocess.run(["python3", "code/app.py"])
subprocess.run(f"exec gunicorn -b 0.0.0.0:9080 -w {(cpu_count() * 2) + 1} code.app:app", shell=True)