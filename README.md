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

Copy the script into your `lib/tasks` of your Decidim installation:

```
cd lib/tasks
wget -qO- https://github.com/Platoniq/decidim-scripts/archive/0.2.tar.gz | tar --transform 's/^decidim-scripts-0.2//' -xvz
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
curl --upload-file geolocs.csv https://transfer.sh/geolocs.csv -H "Max-Days: 1"
```

Which will return (for instance) the download addresses:

```
https://transfer.sh/23lG7/pam-ciutat.csv
https://transfer.sh/YwYAN/pam-districte.csv
https://transfer.sh/x3hUa/geolocs.csv
```

2. Login into a shell session in heroku

```
heroku run bash
```

3. Download the files inside the dyno:

```
wget https://transfer.sh/23lG7/pam-ciutat.csv
wget https://transfer.sh/YwYAN/pam-districte.csv
wget https://transfer.sh/x3hUa/golocs.csv
```

4. Download the scripts into the `lib/tasks` folder:

```
wget -qO- https://github.com/Platoniq/decidim-scripts/archive/0.2.tar.gz | tar --transform 's/^decidim-scripts-0.2//' -xvz -C lib/tasks
```

5. Run the script inside the shell session (2nd terminal):

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