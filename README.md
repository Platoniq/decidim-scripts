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

Importing massive answers for proposals
---------------------------------------

This script answers a list of proposals, it requires an excel with headers with this format:

```
ID, status, text_ca, text_es, ...
123, accepted, una resposta, una respuesta, ... 
```

or

``` 
id, state, answer/ca, answer/es, ...
123, acceptada, una resposta, una respuesta, ... 
```

> NOTE: 
> - Component setting "Publish proposal answers immediately" is honored, so, if activated, emails and notifications will be sent. Otherwise will just introduce the answers in the database.
> - Answers are are parsed to highlight links automatically and convert line breaks to `<br>`;

### Usage:

Copy the script into your `lib/tasks` of your Decidim installation:

```
cd lib/tasks
wget -qO- https://github.com/Platoniq/decidim-scripts/archive/0.4.tar.gz | tar --transform 's/^decidim-scripts-0.4//' -xvz
```

Run in local (as testing):

```
bin/rails "proposals:batch:answer[admin@example.org,./proposal-answers.csv]"
```

Massively geolocating proposals
-------------------------------

This script geolocates a list of proposals, it requires an excel with headers with this format:

```
ID, address, ...
123, some place, ... 
```

or

``` 
i, adreça, ...
123, some place, ... 
```

> NOTE: 
> - Component setting "Geocoding enabled" is honored, so, if not activated, proposals won't be modified.

```
bin/rails proposals:batch:geoloc[admin@example.org,./proposal-geolocs.csv]
```

Running in heroku:
------------------

In Heroku you need to temporary copy the relevant files into a running container first.
As there's no "copy" command to do that you can use the service https://transfer.sh with this trick:


1. From your computer, send the files to transfer.sh:

```
curl --upload-file proposal-answerss.csv https://transfer.sh/proposal-answers.csv -H "Max-Days: 1"
curl --upload-file proposal-geolocs.csv https://transfer.sh/proposal-geolocs.csv -H "Max-Days: 1"
```

Which will return (for instance) the download addresses:

```
https://transfer.sh/YwYAN/proposal-answers.csv
https://transfer.sh/x3hUa/proposal-geolocs.csv
```

2. Login into a shell session in heroku

```
heroku run bash
```

3. Download the files inside the dyno:

```
wget https://transfer.sh/YwYAN/proposal-answers.csv
wget https://transfer.sh/x3hUa/proposal-geolocs.csv
```

4. Download the scripts into the `lib/tasks` folder:

```
wget -qO- https://github.com/Platoniq/decidim-scripts/archive/0.4.tar.gz | tar --transform 's/^decidim-scripts-0.4//' -xvz -C lib/tasks
```

5. Run the script inside the shell session (2nd terminal):

```
bin/rails proposals:batch:answer
bin/rails proposals:batch:geoloc
```

or:

```
bin/rails proposals:batch:answer[admin@example.org,./proposal-answerss.csv]
bin/rails proposals:batch:geoloc[admin@example.org,./proposal-geolocs.csv]
```

NOTE: in case the program runs out of  memory in Redis, just execute it again after a minute or so to allow for the queue to empty.