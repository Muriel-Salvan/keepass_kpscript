describe KeepassKpscript::Database do

  shared_examples 'a database' do

    subject(:database) { kpscript.open('/path/to/my_db.kdbx', password: 'MyPassword') }

    let(:kpscript) { KeepassKpscript.use('/path/to/KPScript.exe', debug: debug) }

    it 'gets a simple password for an entry title' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          <<~EO_STDOUT
            MyEntryPassword
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(database.password_for('MyEntryTitle')).to eq 'MyEntryPassword'
    end

    it 'fails with an error silencing secrets when KPScript returns a non-zero exit status' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          {
            stdout: '',
            exit_status: 1
          }
        ]
      ]
      expect { database.password_for('MyEntryTitle') }.to raise_error 'Error while executing /path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"XXXXX" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password" (exit status: 1)'
    end

    it 'fails with an error silencing secrets when KPScript returns an error message' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password"',
          'E: Error reading database.'
        ]
      ]
      expect { database.password_for('MyEntryTitle') }.to raise_error 'Error returned by /path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"XXXXX" -c:GetEntryString -ref-Title:"MyEntryTitle" -Field:"Password": E: Error reading database.'
    end

    it 'reads entries string' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:GetEntryString -refx-All -Field:"Field"',
          <<~EO_STDOUT
            Value1
            Value2
            Value3
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      expect(database.entries_string(kpscript.select.all, 'Field')).to eq %w[Value1 Value2 Value3]
    end

    it 'reads entries string in a secured way with secret strings' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:GetEntryString -refx-All -Field:"Field"',
          <<~EO_STDOUT
            Value1
            Value2
            Value3
            OK: Operation completed successfully.
          EO_STDOUT
        ]
      ]
      leaked_values = nil
      expect do
        database.with_entries_string(kpscript.select.all, 'Field') do |values|
          expect(values.map(&:to_s)).to eq %w[XXXXX XXXXX XXXXX]
          expect(values.map(&:to_unprotected)).to eq %w[Value1 Value2 Value3]
          leaked_values = values
        end
      end.not_to raise_error
      expect(leaked_values.map(&:to_s)).to eq %w[XXXXX XXXXX XXXXX]
      expect(leaked_values.map(&:to_unprotected)).to eq ["\x00\x00\x00\x00\x00\x00", "\x00\x00\x00\x00\x00\x00", "\x00\x00\x00\x00\x00\x00"]
    end

    {
      fail_if_not_exists: '-FailIfNotExists',
      fail_if_no_entry: '-FailIfNoEntry',
      spr: '-Spr'
    }.each do |keyword, kpscript_flag|

      it "reads entries string with #{keyword} flag" do
        expect_calls_to_kpscript [
          [
            "/path/to/KPScript.exe \"/path/to/my_db.kdbx\" -pw:\"MyPassword\" -c:GetEntryString -refx-All -Field:\"Field\" #{kpscript_flag}",
            <<~EO_STDOUT
              Value1
              Value2
              Value3
              OK: Operation completed successfully.
            EO_STDOUT
          ]
        ]
        expect(database.entries_string(kpscript.select.all, 'Field', **{ keyword => true })).to eq %w[Value1 Value2 Value3]
      end

      it "reads entries string in a secured way with secret strings with #{keyword} flag" do
        expect_calls_to_kpscript [
          [
            "/path/to/KPScript.exe \"/path/to/my_db.kdbx\" -pw:\"MyPassword\" -c:GetEntryString -refx-All -Field:\"Field\" #{kpscript_flag}",
            <<~EO_STDOUT
              Value1
              Value2
              Value3
              OK: Operation completed successfully.
            EO_STDOUT
          ]
        ]
        leaked_values = nil
        expect do
          database.with_entries_string(kpscript.select.all, 'Field', **{ keyword => true }) do |values|
            expect(values.map(&:to_s)).to eq %w[XXXXX XXXXX XXXXX]
            expect(values.map(&:to_unprotected)).to eq %w[Value1 Value2 Value3]
            leaked_values = values
          end
        end.not_to raise_error
        expect(leaked_values.map(&:to_s)).to eq %w[XXXXX XXXXX XXXXX]
        expect(leaked_values.map(&:to_unprotected)).to eq ["\x00\x00\x00\x00\x00\x00", "\x00\x00\x00\x00\x00\x00", "\x00\x00\x00\x00\x00\x00"]
      end

    end

    # All edit entries test cases
    {
      { fields: { Field: 'Value' } } => '-set-Field:"Value"',
      { fields: { Field1: 'Value1', Field2: 'Value2' } } => '-set-Field1:"Value1" -set-Field2:"Value2"',
      { icon_idx: 7 } => '-setx-Icon:7',
      { custom_icon_idx: 11 } => '-setx-CustomIcon:11',
      { expires: true } => '-setx-Expires:true',
      { expiry_time: Time.parse('2021-06-30 15:12:11') } => '-setx-ExpiryTime:"2021-06-30T15:12:11"',
      { fields: { Field: 'Value' }, create_backup: true } => '-set-Field:"Value" -CreateBackup',
      {
        fields: { Field1: 'Value1', Field2: 'Value2' },
        expiry_time: Time.parse('2021-06-30 15:12:11'),
        icon_idx: 7,
        create_backup: true
      } => '-set-Field1:"Value1" -set-Field2:"Value2" -setx-Icon:7 -setx-ExpiryTime:"2021-06-30T15:12:11" -CreateBackup'
    }.each do |kwargs, expected_args|

      it "edit entries using #{kwargs}" do
        expect_calls_to_kpscript [
          [
            "/path/to/KPScript.exe \"/path/to/my_db.kdbx\" -pw:\"MyPassword\" -c:EditEntry -refx-All #{expected_args}",
            'OK: Operation completed successfully.'
          ]
        ]
        expect { database.edit_entries(kpscript.select.all, **kwargs) }.not_to raise_error
      end

    end

    it 'detaches binaries' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:DetachBins',
          'OK: Operation completed successfully.'
        ]
      ]
      expect { database.detach_bins }.not_to raise_error
    end

    it 'detaches binaries in another directory' do
      tmpdir = "#{Dir.tmpdir}/keepass_kpscript_test"
      FileUtils.mkdir_p tmpdir
      begin
        database_file = "#{tmpdir}/my_db.kdbx"
        File.write(database_file, 'Dummy database')
        bins_dir = "#{tmpdir}/bins_dir"
        expect_calls_to_kpscript [
          [
            "/path/to/KPScript.exe \"#{bins_dir}/my_db.kdbx.tmp.kdbx\" -pw:\"MyPassword\" -c:DetachBins",
            'OK: Operation completed successfully.'
          ]
        ]
        expect { kpscript.open(database_file, password: 'MyPassword').detach_bins(copy_to_dir: bins_dir) }.not_to raise_error
        expect(File.exist?(bins_dir)).to eq true
        # Check that no database copy is remaining
        expect(Dir.glob("#{bins_dir}/*")).to eq []
      ensure
        FileUtils.rm_rf tmpdir
      end
    end

    it 'exports the database' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:Export -Format:"Export Format" -OutFile:"/path/to/export_file"',
          'OK: Operation completed successfully.'
        ]
      ]
      expect { database.export('Export Format', '/path/to/export_file') }.not_to raise_error
    end

    it 'exports the database with a group path selected' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:Export -Format:"Export Format" -OutFile:"/path/to/export_file" -GroupPath:"Group1/Group2/Group3"',
          'OK: Operation completed successfully.'
        ]
      ]
      expect { database.export('Export Format', '/path/to/export_file', group_path: %w[Group1 Group2 Group3]) }.not_to raise_error
    end

    it 'exports the database with an XSL file specified' do
      expect_calls_to_kpscript [
        [
          '/path/to/KPScript.exe "/path/to/my_db.kdbx" -pw:"MyPassword" -c:Export -Format:"Export Format" -OutFile:"/path/to/export_file" -XslFile:"/path/to/xsl_file.xsl"',
          'OK: Operation completed successfully.'
        ]
      ]
      expect { database.export('Export Format', '/path/to/export_file', xsl_file: '/path/to/xsl_file.xsl') }.not_to raise_error
    end

  end

  context 'without debug' do

    it_behaves_like 'a database' do
      let(:debug) { false }
    end

  end

  context 'with debug' do

    it_behaves_like 'a database' do
      let(:debug) { true }
    end

  end

end
