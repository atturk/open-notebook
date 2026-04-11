# Come funzionano i Backup

Il terminale deve essere nella cartella open-notebook

## Creare backup
`./backup.sh full`

## Vedere quali backup ci sono
`ls -lh ~/documents/open-notebook/backups/`

## Ripristinare backup
`./restore.sh backups/backup_full_YYYYMMDD_HHMMSS.tar.gz`