# Completion per ujust: elenca le ricette del justfile di sistema Atomik
complete -c ujust -f -a "(ujust --summary 2>/dev/null | string split ' ')"