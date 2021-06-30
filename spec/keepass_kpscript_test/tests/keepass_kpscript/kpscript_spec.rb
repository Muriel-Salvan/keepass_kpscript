describe KeepassKpscript::Kpscript do

  shared_examples 'a kpscript instance' do

    subject(:kpscript) { KeepassKpscript.use('/path/to/KPScript.exe', debug: debug) }

    it 'gives an instance wrapping a KPScript installation' do
      expect_calls_to_kpscript [['/path/to/KPScript.exe -example-arg', 'OK: Operation completed successfully.']]
      kpscript.run('-example-arg')
    end

    it 'encrypts passwords' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/tmp/keepass_kpscript.tmp.kdbx" -pw:"pass_encryptor" -c:EditEntry -ref-Title:"pass_encryptor" -set-Password:"MyPassword"',
          'OK: Operation completed successfully.'
        ],
        [
          '/path/to/KPScript.exe "/tmp/keepass_kpscript.tmp.kdbx" -pw:"pass_encryptor" -c:GetEntryString -ref-Title:"pass_encryptor" -Field:"URL" -Spr',
          <<~EO_STDOUT
            ENCRYPTED_PASSWORD
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(kpscript.encrypt_password('MyPassword')).to eq 'ENCRYPTED_PASSWORD'
    end

    it 'opens a database with a password' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          <<~EO_STDOUT
            MyEntryPassword
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(kpscript.open('/path/to/my_db.kdbx', password: 'MyPassword').password_for('MyEntryTitle')).to eq 'MyEntryPassword'
    end

    it 'opens a database with an encrypted password' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw-enc:"MyEncryptedPassword" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          <<~EO_STDOUT
            MyEntryPassword
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(kpscript.open('/path/to/my_db.kdbx', password_enc: 'MyEncryptedPassword').password_for('MyEntryTitle')).to eq 'MyEntryPassword'
    end

    it 'opens a database with a key file' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -keyfile:"/path/to/key_file" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          <<~EO_STDOUT
            MyEntryPassword
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(kpscript.open('/path/to/my_db.kdbx', key_file: '/path/to/key_file').password_for('MyEntryTitle')).to eq 'MyEntryPassword'
    end

    it 'opens a database with a key file and password' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -keyfile:"/path/to/key_file" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          <<~EO_STDOUT
            MyEntryPassword
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(kpscript.open('/path/to/my_db.kdbx', password: 'MyPassword', key_file: '/path/to/key_file').password_for('MyEntryTitle')).to eq 'MyEntryPassword'
    end

    it 'opens a database with a key file and encrypted password' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw-enc:"MyEncryptedPassword" -keyfile:"/path/to/key_file" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          <<~EO_STDOUT
            MyEntryPassword
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(kpscript.open('/path/to/my_db.kdbx', password_enc: 'MyEncryptedPassword', key_file: '/path/to/key_file').password_for('MyEntryTitle')).to eq 'MyEntryPassword'
    end

    it 'gives a selector' do
      expect_calls_to_kpscript []
      expect(kpscript.select.fields(Title: 'MyEntryTitle').to_s).to eq '-ref-Title:"MyEntryTitle"'
    end

  end

  context 'without debug' do

    it_behaves_like 'a kpscript instance' do
      let(:debug) { false }
    end

  end

  context 'with debug' do

    it_behaves_like 'a kpscript instance' do
      let(:debug) { true }
    end

  end

end
