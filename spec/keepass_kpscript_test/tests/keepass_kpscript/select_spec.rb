describe KeepassKpscript::Select do

  shared_examples 'a selector' do

    subject(:selector) { KeepassKpscript.use('/path/to/KPScript.exe', debug: debug).select }

    {
      proc { |s| s.fields(Field: 'Value') } => '-ref-Field:"Value"',
      proc { |s| s.fields(Field1: 'Value1', Field2: 'Value2') } => '-ref-Field1:"Value1" -ref-Field2:"Value2"',
      proc { |s| s.fields(Field1: 'Value1').fields(Field2: 'Value2') } => '-ref-Field1:"Value1" -ref-Field2:"Value2"',
      proc { |s| s.uuid('MyUUID') } => '-refx-UUID:MyUUID',
      proc { |s| s.tags %w[tag1 tag2] } => '-refx-Tags:"tag1,tag2"',
      proc { |s| s.tags(*%w[tag1 tag2]) } => '-refx-Tags:"tag1,tag2"',
      proc { |s| s.expires } => '-refx-Expires:true',
      proc { |s| s.expires(false) } => '-refx-Expires:false',
      proc { |s| s.expired } => '-refx-Expired:true',
      proc { |s| s.expired(false) } => '-refx-Expired:false',
      proc { |s| s.group('MyGroup') } => '-refx-Group:"MyGroup"',
      proc { |s| s.group_path %w[Group1 Group2 Group3] } => '-refx-GroupPath:"Group1/Group2/Group3"',
      proc { |s| s.group_path(*%w[Group1 Group2 Group3]) } => '-refx-GroupPath:"Group1/Group2/Group3"',
      proc { |s| s.all } => '-refx-All',
      proc do |s|
        # Check here that all methods are chainable
        s.
          group('MyGroup').
          expires.
          expired(false).
          tags('MyTag').
          fields(Field: 'Value').
          uuid('MyUUID').
          group_path(%w[Group1 Group2]).
          all.
          fields(Field1: 'Value1', Field2: 'Value2')
      end => '-refx-Group:"MyGroup" -refx-Expires:true -refx-Expired:false -refx-Tags:"MyTag" -ref-Field:"Value" -refx-UUID:MyUUID -refx-GroupPath:"Group1/Group2" -refx-All -ref-Field1:"Value1" -ref-Field2:"Value2"'
    }.each.with_index do |(select_block, expected_args), example_idx|

      it "selects #{expected_args} (example ##{example_idx})" do
        expect(select_block.call(selector).to_s).to eq expected_args
      end

    end

  end

  context 'without debug' do

    it_behaves_like 'a selector' do
      let(:debug) { false }
    end

  end

  context 'with debug' do

    it_behaves_like 'a selector' do
      let(:debug) { true }
    end

  end

end
