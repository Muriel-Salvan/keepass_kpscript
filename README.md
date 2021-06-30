[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)

# keepass_kpscript - Ruby API to handle Keepass databases using KPScript

## Description

This Rubygem gives you ways to handle [KeePass databases](https://keepass.info/) using the [KPScript KeePass plugin](https://keepass.info/plugins.html#kpscript).

Other Rubygems handling KeePass databases usually handle the databases format themselves and can get obsolete if not kept up-to-date with the new file specifications.

`keepass_kpscript` uses the official KPScript plugin installed with a KeePass installation to handle databases, so that the risk of specifications' obsolescence is low (unless KPScript changes its command-line interface). However the cons of this approach is that `keepass_kpscript` needs a local installation of KeePass and KPScript to run.

Works for both Windows and Linux installations of KPScript.

## Requirements

* [KeePass](https://keepass.info/) - To be installed locally.
* [KPScript KeePass plugin](https://keepass.info/plugins.html#kpscript) - To be installed in your KeePass installation (follow the install instructions from the KPScript documentation).

## Install

Via gem command line:

```bash
gem install keepass_kpscript
```

If using `bundler`, add this in your `Gemfile`:

```ruby
gem 'keepass_kpscript'
```

## Usage

Basically you just need to tell `keepass_kpscript` the KPScript command-line to be used (with `KeepassKpscript.use`), and the API will give you access to KPScript API to handle KeePass databases.

```ruby
require 'keepass_kpscript'

# Let's use the system KeePass (under Windows, enclose it within "" for paths containing spaces like 'Program Files')
kpscript = KeepassKpscript.use('"C:\Program Files\KeePass\KPScript.exe"')

# Open a database with a simple password
database = kpscript.open('C:\Data\MyDatabase.kdbx', password: 'MyP4$sW0rD')

# Read a password for an entry
google_password = database.password_for 'Google Account'
puts "Password for 'Google Account' is #{google_password}"
```

Now that you get the basic usage, you can see the following sections for more features.

### Using key files, passwords and encrypted passwords to open databases

The [`Kpscript#open`](lib/keepass_kpscript/kpscript.rb) method accepts the following parameters while opening a database:
* `password`: The password to be used.
* `password_enc`: The encrypted password to be used (can be used in place of the password). You can use the [`Kpscript#encrypt_password`](lib/keepass_kpscript/kpscript.rb) method to generates an encrypted password from a password.
* `key_file`: Path to the key file to be used.

Example: open a database protected both by a password and a key file, and use an encrypted version of the password to open it.

```ruby
encrypted_password = kpscript.encrypt_password('MyP4$sW0rD')

# This will not use the real password on KPScript command-line, which is better security wise.
database = kpscript.open('C:\Data\MyDatabase.kdbx', password_enc: encrypted_password, key_file: 'C:\Data\Database.key')
```

### Read entries from a database

The most versatile method to read database content is [`Database#entries_string`](lib/keepass_kpscript/database.rb), which maps directly the [`GetEntryString` KPScript method](https://keepass.info/help/v2_dev/scr_sc_index.html#getentrystring).

It uses chainable selectors to select the entries to be read, based on field names, uuids...

Example: read the URL field of all entries tagged `production` belonging to the group `Azure`
```ruby
database.entries_string(kpscript.select.tags('production').group('Azure'), 'URL').each do |url|
  puts "Found URL: #{url}"
end
```

A more secure way to read secrets from a database is by using [`Database#with_entries_string`](lib/keepass_kpscript/database.rb) that works with a code block and the same parameters as [`Database#entries_string`](lib/keepass_kpscript/database.rb). The benefits are:
* Any variable that would have been read will be erased from memory at the end of the code execution, so that no attacker can eventually read it from memory, code injection, or memory dump on disk.
* The secret strings given to the code will be [`SecretString`](https://github.com/Muriel-Salvan/secret_string) instead of a String, that will guard the secret from being revealed in common Ruby operations (logging, screen output...), unless the `to_unprotected` method is used on it. Better way to control accessibility of your secrets!

Example: read all the passwords of entries belonging to Google's URL, and make sure those passwords are removed from memory after usage (and even try to leak the password in memory_)
```ruby
# Try to leak the password (simulating a security vulnerability here)
leaked_password = nil

database.with_entries_string(kpscript.select.fields(URL: '//google.com//'), 'Password').each do |password|
  puts "Displayed password: #{password}"
  # => Displayed password: XXXXX
  puts "Now we REALLY want to display the password: #{password.to_unprotected}"
  # => Now we REALLY want to display the password: MyP4$sW0rD
  leaked_password = password
end

# Now that we are out of the code block, let's try to use the password again, hehe }:->
puts "Displayed leaked password: #{leaked_password.to_unprotected}"
# => Displayed leaked password:
```

To know more:
* The possible field references are documented in [KeePass documentation](https://keepass.info/help/base/fieldrefs.html).
* The possible selectors that can be used on the `Kpscript#select` call are methods defined in [the `Select` class](lib/keepass_kpscript/select.rb).

### Edit entries in a database

[`Database#edit_entries`](lib/keepass_kpscript/database.rb) can be used to edit entries. It maps the [`EditEntry` KPScript method](https://keepass.info/help/v2_dev/scr_sc_index.html#editentry) functionality.

The API uses the same selectors' logic as [`Database#entries_string`](lib/keepass_kpscript/database.rb).

Example: add notes and set the icon index 5 to all entries having a Google URL
```ruby
database.edit_entries(
  kpscript.select.fields(URL: '//google.com//'),
  fields: { Notes: 'It\'s for Google' },
  icon_idx: 5
)
```

### Export a database

[`Database#export`](lib/keepass_kpscript/database.rb) maps the [`Export` KPScript method](https://keepass.info/help/v2_dev/scr_sc_index.html#export) to export databases.

```ruby
database.export('KeePass XML (2.x)', 'my_export.xml')
```

### Detach binaries (attachments) from a database

[`Database#detach_bins`](lib/keepass_kpscript/database.rb) maps the [`DetachBins` KPScript method](https://keepass.info/help/v2_dev/scr_sc_index.html#detachbins) to extract files from databases.

Be careful that by default this method modifies your database by removing the attached files from it and writing them next to it.
If you want to keep your database intact, you can use the `copy_to_dir` option and it will extract files without removing them to antoher directory.

```ruby
# Extract all files from database into the ./my_files sub-folder.
database.detach_bins(copy_to_dir: 'my_files')

# Extract and remove all files from database next to the database file.
database.detach_bins
```

## Change log

Please see [CHANGELOG](CHANGELOG.md) for more information on what has changed recently.

## Testing

Automated tests are done using rspec.

To execute them, first install development dependencies:

```bash
bundle install
```

Then execute rspec

```bash
bundle exec rspec
```

## Contributing

Any contribution is welcome:
* Fork the github project and create pull requests.
* Report bugs by creating tickets.
* Suggest improvements and new features by creating tickets.

## Credits

- [Muriel Salvan](https://x-aeon.com/muriel)

## License

The BSD License. Please see [License File](LICENSE.md) for more information.
