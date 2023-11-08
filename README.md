<div align="center">
  
![vm-builder](https://github.com/MinerAle00/vmbuilder/assets/66887063/8005bd67-1c8c-4d6c-ab51-3ad0da63c311)
</div>

Questo script è stato testato e funziona con Proxmox 7 e 8. Se ci sono problemi, per favore segnalali e li esaminerò. Assicurati anche di avere impostato gli snippet perché sembra essere un problema comune durante l'esecuzione dello script, quindi assicurati che gli snippet siano configurati in proxmox o potrebbero sorgere problemi. Mi occuperò di aggiornare le immagini cloud disponibili.

*****************************
<div align="center">
  
https://github.com/MinerAle00/vmbuilder/assets/66887063/d38db6bd-6409-4ab1-a605-c186cde6d696
</div>
*****************************

<h2 align="left">📑 Descrizione</h2>

Puoi avere una macchina virtuale creata e avviata con le informazioni che hai impostato entro due minuti. Viene scaricata l'ultima immagine cloud disponibile (se necessario) e può essere impostata con diverse impostazioni.

Questo script può essere utilizzato dai principianti che non conoscono ancora molto su Proxmox, oppure può essere utilizzato dagli utenti avanzati per avviare rapidamente diverse macchine virtuali.

<h2 align="left"> 💻 Utilizzo</h2>
<ul>
  <li>Scarica lo script vmbuilder.sh da questa repository nel tuo nodo di proxmox</li>
  <li>Esegui chmod +x vmbuilder.sh</li>
  <li>Se utilizzi le chiavi ssh devi conoscere la cartella</li>
  <li>Assicurati che gli snippets siano abilitati nel tuo storage. Nella GUI di Proxmox vai su Datacenter, Storage e puoi vedere se sono abilitati o no</li>
  <li>Esegui lo script con ./vmbuilder.sh</li>
  <li>Segui quello che ti dice lo script e sei pronto ad avere la tua macchina virtuale in pochissimo tempo!</li>
</ul>

<h2 align="left"> 💿 Immagini disponibili</h2>
<ul>
  <li>Ubuntu Lunar 23.10</li>
  <li>Ubuntu Jammy 22.04</li>
  <li>Ubuntu Focal 20.04</li>
  <li>CentOS 8</li>
  <li>CentOS 7</li>
  <li>Debian 12</li>
  <li>Debian 11</li>
  <li>Arch Linux</li>
  <li>Fedora 39</li>
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
   <li>Nome VM</li>
   <li>Numero VM (viene comunque controllato se il numero assegnato è già presente sui nodi Proxmox)</li>
   <li>Username</li>
   <li>Password</li>
   <li>Aggiungi una chiave SSH (ad esempio id_rsa.pub)</li>
   <li>Autenticazione SSH utilizzando la password (le chiavi sono molto più sicuri)</li>
   <li>Seleziona lo storage per la VM</li>
   <li>Seleziona lo storage per la tua ISO</li>
   <li>Seleziona lo storage per i file snippet (per il file user.yml)</li>
   <li>Seleziona se vuoi utilizzare il DHCP o l'IP statico</li>
   <li>Seleziona il numero della VLAN</li>
   <li>Seleziona se vuoi aumentare lo spazio della Cloud Image</li>
   <li>Seleziona il numero di core e la ram da dedicare alla VM</li>
   <li>Scegli se vuoi installare automaticamente i qemu-guest-agent (altamente consigliato!)</li>
   <li>Seleziona su che nodo di Proxmox vuoi che la macchina virtuale funzioni</li>
</ul>

<h2 align="left">🔮 Aggiornamenti futuri</h2>
    <li>✅ Cancellare immagini obsolete</li>
    <li>✅ Alma Linux</li>
    <li>✅ Rocky Linux</li>
    <li>👨🏻‍💻 Pacchetti aggiuntivi</li>
    <li>👨🏻‍💻 Traduzione script</li>
