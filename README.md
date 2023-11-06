
<h2 align="center"> 🚨 Lo script è in aggiornamento 🚨</h2>


Questo script è stato testato e funziona con Proxmox 7 e 8. Se ci sono problemi, per favore segnalali e li esaminerò. Assicurati anche di avere impostato gli snippet perché sembra essere un problema comune durante l'esecuzione dello script, quindi assicurati che gli snippet siano configurati in proxmox o potrebbero sorgere problemi. Mi occuperò di aggiornare le immagini cloud disponibili.

*****************************

<h2 align="left">📑 Descrizione</h2>

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
  <li>Ubuntu Lunar 23.10</li>
  <li>Ubuntu Jammy 22.04</li>
  <li>Ubuntu Focal 20.04</li>
  <li>CentOS 8</li>
  <li>CentOS 7</li>
  <li>Debian 12</li>
  <li>Debian 11</li>
  <li>Arch Linux</li>
  <li>Fedora 38</li>
  <li>Rocky Linux 9.2</li>
  <li>AlmaLinux OS 9.2</li>
</ul>

<h2 align="left">⚙️ Funzionalità</h2>
 Se ti trovi in un ambiente di cluster, puoi scegliere il nodo Proxmox su cui desideri avere la macchina virtuale (tramite qm migrate)
 Se non hai l'immagine, il programma la scaricherà per te.
 Il programma crea un file user.yaml e lo aggiunge come snippet, in modo da poter personalizzare molti aspetti della macchina virtuale dell'immagine cloud durante la creazione (Consulta la Wiki di Proxmox per ulteriori informazioni sugli snippet).
 Il programma verifica quali spazi di archiviazione sono disponibili sul nodo Proxmox e puoi selezionare quello che desideri utilizzare.
 Il programma verifica quali spazi di archiviazione degli snippet sono disponibili sul nodo Proxmox e puoi selezionare quello che desideri utilizzare.
 Puoi personalizzare:
 <ul>
   <li>Hostname
   <li>ID number (It checks ID's in the entire cluster and also provides next number if you don't use custom numbers)</li>
   <li>Username</li>
   <li>Password</li>
   <li>Add a SSH key file (example id_rsa.pub)</li>
   <li>Asks if you want to enable SSH password authentication (Keys are safer)</li>
   <li>Select storage you want to run the Virtual Machine on</li>
   <li>Select the storage location of your ISO files</li>
   <li>Select the storage and location of your snippet files (for user.yaml)</li>
   <li>Check if you want to use DHCP or enter Static IP</li>
   <li>If you want to enter a VLAN number</li>
   <li>If you want to resize the cloud image storage so you can have more space</li>
   <li>It lets you set the number of cores and memory for the Virtual Machine</li>
   <li>Asks if you want it to install qemu-guest-agent (see Proxmox's wiki for more infomation) - Great to have out of the box from the Admin side of Proxmox</li>
   <li>Added the option to start after creation or not to start</li>
   <li>Asks what Proxmox node to have the VM running after all is complete</li>
   <li>Makes it simple to learn some of the CLI of proxmox (by reviewing the script) and some awesome built in featues of Proxmox to get things up and running fast and easily</li>
</ul>

<h2 align="left">🔮 Aggiornamenti futuri</h2>
    <li>✅ Cancellare immagini obsolete</li>
    <li>✅ Alma Linux</li>
    <li>✅ Rocky Linux</li>
    <li>✅ Pacchetti aggiuntivi</li>
    <li>❗ Traduzione script</li>
