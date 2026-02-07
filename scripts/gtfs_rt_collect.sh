# Count number of files per day
$ ls -l --time-style=+%Y-%m-%d CarrisMetropolitana/ | awk '{print $6}' | sort | uniq -c

# Zip only some days
$ zip cmet_20260202_20260206.zip CarrisMetropolitana/20260202_*.json CarrisMetropolitana/20260203_*.json CarrisMetropolitana/20260204_*.json CarrisMetropolitana/20260205_*.json CarrisMetropolitana/20260206_*.json

