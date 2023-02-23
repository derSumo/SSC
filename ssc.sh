#!/bin/bash

#Script Update Funktion
# Define variables
REPO_URL="https://github.com/derSumo/SSC.git"
SCRIPT_NAME="ssh.sh"
TEMP_DIR=$(mktemp -d)
CURRENT_DIR=$(pwd)

# Clone the latest version of the repo into a temporary directory
git clone $REPO_URL $TEMP_DIR

# Check if the script has been updated
cd $TEMP_DIR
REMOTE_HASH=$(git rev-parse HEAD)
cd $CURRENT_DIR
LOCAL_HASH=$(git rev-parse HEAD)

if [ "$REMOTE_HASH" != "$LOCAL_HASH" ]; then
  # The script has been updated, so replace the current version with the latest one
  echo "Updating script..."
  cp $TEMP_DIR/$SCRIPT_NAME $CURRENT_DIR/$SCRIPT_NAME
  chmod +x $CURRENT_DIR/$SCRIPT_NAME
  echo "Script updated successfully."
fi

# Clean up the temporary directory
rm -rf $TEMP_DIR

# Run the script
./$SCRIPT_NAME





# Funktion zum Updaten des Systems
function updateSystem {
    # Aktualisiere die Paketlisten
    echo "Aktualisiere Paketlisten..."
    apt-get update > /dev/null 2>&1

    # Installiere alle verfügbaren Updates
    echo "Installiere verfügbare Updates..."
    apt-get upgrade -y > /dev/null 2>&1 &

    # Speichere den PID des laufenden Prozesses
    pid=$!

    # Initialisiere den Ladebalken
    spin='-\|/'
    i=0

    while kill -0 $pid 2>/dev/null
    do
      i=$(( (i+1) %4 ))
      printf "\r${spin:$i:1}"
      sleep .1
    done

    # Füge eine Zeile hinzu, um den Ladebalken von der vorherigen Ausgabe zu trennen
    echo ""

    # Überprüfe, ob das Upgrade erfolgreich war
    if [ $? -eq 0 ]
    then
      echo "Das Upgrade wurde erfolgreich durchgeführt."
    else
      echo "Das Upgrade ist fehlgeschlagen."
    fi
}

# Funktion zum Löschen von alten datein,kernel,temp
function clearOldSystem {
    # Lösche alle Pakete, die nicht mehr benötigt werden
    apt-get autoremove -y
	# Lösche alle alten Kernel und Kernel-Header
	#dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs apt-get -y purge

	# Lösche alle temporären Dateien
	rm -rf /tmp/*

	# Lösche alle Log-Dateien, die älter als 7 Tage sind
	find /var/log/ -mtime +7 -exec rm {} \;

	# Lösche alle Thumbnail-Dateien, die älter als 30 Tage sind
	find ~/.cache/thumbnails -type f -mtime +30 -delete
  echo "Temp und alte System Daten wurden erfolgreich entfernt."
  sleep 2
	clear
}

# Löschen des Systemcaches unter Debian
function cacheSystem {
	# Als erstes müssen wir sicherstellen, dass wir root-Rechte haben
	if [[ $(id -u) -ne 0 ]]
	then
	   echo "Das Skript muss als root ausgeführt werden."
	   exit 1
	fi

	# Danach können wir den Cache löschen
	sync
	echo 3 > /proc/sys/vm/drop_caches

	echo "Der Systemcache wurde gelöscht."
  sleep 2
  clear
}

# Funktion zum Anhalten und Updaten von Docker-Containern
function updateDockerContainers {
  # Stelle eine Liste aller laufenden Docker-Container bereit
  containers=$(docker ps -q)

  # Aktualisiere jedes Docker-Image
  for container in $containers
  do
    docker pull $(docker inspect --format='{{index .Config.Image}}' $container)
  done

  # Starte jeden Docker-Container mit dem neuesten Image neu
  for container in $containers
  do
    docker stop $container
    docker rm $container
    docker run -d $(docker inspect --format="{{.HostConfig}} {{.Config.Image}}" $container)
  done
}

# Entferne alle unused Docker images
function unusedDockerContainers {
    # Entferne alle ungenutzen Docker Images Text
    echo "Entferne alle ungenutze Docker Images..."

    # Erstellt eine liste von ungenutzen Docker Images
    unused_images=$(docker images -f "dangling=true" -q)

    # Wenn die List nicht leer ist, dann entferne alle ungenutzen Images
    if [ -n "$unused_images" ]; then
    	docker rmi $unused_images
    else
    	echo "Es gibt keine ungenutzen Docker Images zum Entfernen"
    fi
}

# Leere Order Entfernen
function delete_empty_dir {
  echo "Bitte gebe denn Pfad ein, wo die Leere Order entfernt werden sollen:"
  read filePath
  echo
  clear
  echo
  read -p "Soll [ $filePath ] gelöscht werden? (j/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Jj]$ ]]; then
    echo
    echo "Folgender Order wird bereinigt: $filePath"
    # Hier soll die delete_empty_folder verwendet werden
    delete_empty_folders $filePath
    echo "[ $filePath ] sind keine leere Ordner mehr."
    read
    clear
  fi
  echo "Der Orderbaum [$filePath] wurde nicht beereinigt"
  read
  clear
}
# Hauptmenü anzeigen
while true; do
    echo "--- SumoTV Menu ---"
    echo "1) System updaten"
    echo "2) Docker-Container Updaten"
    echo "3) Ungenutze Docker Images Entfernen"
    echo "4) Bereinige Speicher"
    echo "5) System Cache Clear"
    echo "6) Leere Ordner Entfernen"
    echo "7) Beenden"

    read -p "Wählen Sie eine Option: " option

    case $option in
        1) updateSystem;;
        2) updateDockerContainers;;
        3) unusedDockerContainers;;
	4) clearOldSystem;;
        5) cacheSystem;;
        6) delete_empty_dir;;
	7) exit;;
        *) echo "Ungültige Option. Bitte versuchen Sie es erneut.";;
    esac
done
