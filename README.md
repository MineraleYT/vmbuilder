
** 17/06/2023 **

Questo script funziona ancora in un nuovo ambiente proxmox. Se ci sono problemi, per favore segnalali e li esaminerò. Assicurati anche di avere impostato gli snippet perché sembra essere un problema comune durante l'esecuzione dello script, quindi assicurati che gli snippet siano configurati in proxmox o potrebbero sorgere problemi. Mi occuperò di aggiornare le immagini cloud disponibili.

*****************************


Proxmox Virtual Machine Builder with Cloud Images

Puoi avere una macchina virtuale creata e avviata con le informazioni che hai impostato entro due minuti. Si scarica automaticamente l'immagine cloud se necessario e una volta impostate tutte le informazioni, la avvia automaticamente per te.

Questo script può essere utilizzato dai principianti che non conoscono ancora molto su Proxmox, oppure può essere utilizzato dagli utenti avanzati per avviare rapidamente diverse macchine virtuali. (Consiglio professionale: fornisci la tua chiave di Ansible quando richiesta e quindi esegui il tuo playbook dopo la creazione.)

<h2 align="left"> 💻 Utilizzo</h2>
<ul>
  <li>Scarica lo script vmbuilder.sh da questa repository nel tuo nodo di proxmox</li>
  <li>Esegui chmod +x vmbuilder.sh</li>
  <li>Se utilizzi le chiavi ssh devi conoscere la cartella</li>
  <li>Assicurati che gli snippets siano abilitati nel tuo storage. Nella GUI di Proxmox vai su Datacenter, Storage e puoi vedere se sono abilitati o no</li>
  <li>Esegui lo script con ./vmbuilder.sh</li>
  <li>Segui quello che ti dice lo script e sei pronto ad avere la tua macchina virtuale in pochissimo tempo!</li>
</ul>

<h2 align="left"> 💿 Immagini</h2>
<ul>
  <li>Ubuntu Lunar 23.04</li>
  <li>Ubuntu Jammy 22.04</li>
  <li>Ubuntu Focal 20.04</li>
  <li>Ubuntu 20.04 Minimal</li>
  <li>CentOS 8</li>
  <li>CentOS 7</li>
  <li>Debian 12</li>
  <li>Debian 11</li>
  <li>Arch Linux</li>
  <li>Fedora 38</li>
</ul>


Features
 Se ti trovi in un ambiente di cluster, puoi scegliere il nodo Proxmox su cui desideri avere la macchina virtuale (tramite qm migrate)
 Se non hai l'immagine, il programma la scaricherà per te.
 Il programma crea un file user.yaml e lo aggiunge come snippet, in modo da poter personalizzare molti aspetti della macchina virtuale dell'immagine cloud durante la creazione (Consulta la Wiki di Proxmox per ulteriori informazioni sugli snippet).
 Il programma verifica quali spazi di archiviazione sono disponibili sul nodo Proxmox e puoi selezionare quello che desideri utilizzare.
 Il programma verifica quali spazi di archiviazione degli snippet sono disponibili sul nodo Proxmox e puoi selezionare quello che desideri utilizzare.
 Puoi personalizzare:
   - Hostname
   - ID number (It checks ID's in the entire cluster and also provides next number if you don't use custom numbers)
   - Username
   - Password
   - Add a SSH key file (example id_rsa.pub)
   - Asks if you want to enable SSH password authentication (Keys are safer)
   - Select storage you want to run the Virtual Machine on
   - Select the storage location of your ISO files
   - Select the storage and location of your snippet files (for user.yaml)
   - Check if you want to use DHCP or enter Static IP
   - If you want to enter a VLAN number
   - If you want to resize the cloud image storage so you can have more space
   - It lets you set the number of cores and memory for the Virtual Machine
   - Asks if you want it to install qemu-guest-agent (see Proxmox's wiki for more infomation) - Great to have out of the box from the Admin side of Proxmox
   - Added the option to start after creation or not to start
   - Asks what Proxmox node to have the VM running after all is complete
   - Makes it simple to learn some of the CLI of proxmox (by reviewing the script) and some awesome built in featues of Proxmox to get things up and running fast and easily
  
 Future things for the script

    - clean old images
    - Add an option to use IPV6 or IPV4
    - Alpine Linux
    - Rancher OS works, but auto loads in and does not use username/password but the other variables work
    - Fedora Cloud Image works, but doesn't transfer all user.yaml (like host name) snippet info yet...but works with username/password/sshkeys
    - CentOS 8 Cloud Image works, but doesn't transfer all user.yaml (like host name) snippet info yet...but works with username/password/sshkeys 
