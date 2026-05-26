# Atomik OS Kickstart
# Mostra schermata utente in Anaconda

%include /usr/share/anaconda/interactive-defaults.ks

%anaconda
pwpolicy root --notstrict
pwpolicy user --notstrict
pwpolicy luks --notstrict
%end

# Questo forza Anaconda a mostrare la schermata utente
user --name= --groups=wheel
