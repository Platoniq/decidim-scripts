Scripts for Decidim
===================

Preparation:

Backup a Decidim Database (ie: Decidim preproduction in Heroku):

```
heroku pg:backups:capture
heroku pg:backups:download
```

Import in local for testing:

Create database if needed:
```
cd decidim-barcelona-preprod
bin/rails db:create
```

Import (repeat every time to re-test):

```
pg_restore --verbose --clean --no-acl --no-owner -h localhost -U decidim -d decidim-barcelona_development latest.dump
```

Change the host for testing in localhost:

```
bin/rails c
o=Decidim::Organization.first
o.host="localhost"
o.save
```

1: Importing massive answers for proposals
------------------------------------------

Copy the script:

```
cp proposal_answers.rake ../decidim-barcelona-preprod/lib/tasks
cp geoloc_import.rake ../decidim-barcelona-preprod/lib/tasks
cp script_helpers.rake ../decidim-barcelona-preprod/lib/tasks
```

Run in local (as testing):

```
bin/rails "proposals:batch:answer[admin@example.org,./pam-ciutat.csv]"
```

Running in heroku:

In Heroku you need to temporary copy the relevant files into a running container first.
As there's no "copy" command to do that you can use the service https://transfer.sh with this trick:


1. From your computer, send the files to transfer.sh:

```
curl --upload-file pam-ciutat.csv https://transfer.sh/pam-ciutat.csv -H "Max-Days: 1"
curl --upload-file pam-districtes.csv https://transfer.sh/pam-districte.csv -H "Max-Days: 1"
curl --upload-file proposal_answers.rake https://transfer.sh/proposal_answers.rake -H "Max-Days: 1"
curl --upload-file proposal_answers.rake https://transfer.sh/geoloc_import.rake -H "Max-Days: 1"
curl --upload-file proposal_answers.rake https://transfer.sh/script_helpers.rb -H "Max-Days: 1"
```

Which will return (for instance) the download addresses:

```
https://transfer.sh/23lG7/pam-ciutat.csv
https://transfer.sh/YwYAN/pam-districte.csv
https://transfer.sh/x3hUa/proposal_answers.rake
https://transfer.sh/x4hUa/geoloc_import.rake
https://transfer.sh/x5hUa/script_helpers.rake
```

2. Login into a shell session in heroku

```
heroku run bash
```

3. Download the files inside the dyno:

```
wget https://transfer.sh/23lG7/pam-ciutat.csv
wget https://transfer.sh/YwYAN/pam-districte.csv
wget https://transfer.sh/x3hUa/proposal_answers.rake -O lib/tasks/proposal_answers.rake
wget https://transfer.sh/x4hUa/geoloc_import.rake -O lib/tasks/proposal_answers.rake
wget https://transfer.sh/x5hUa/script_helpers.rake -O lib/tasks/proposal_answers.rake
```

4. Run the script inside the shell session (2nd terminal):

```
bin/rails proposals:batch:answer
bin/rails proposals:batch:geoloc
```

or:

```
bin/rails proposals:batch:answer[admin@example.org,./pam-ciutat.csv]
bin/rails proposals:batch:answer[admin@example.org,./pam-districtes.csv]
bin/rails proposals:batch:geoloc[admin@example.org,./geolocs.csv]
```

NOTE: in case the program runs out of  memory in Redis, just execute it again after a minute or so to allow for the queue to empty.