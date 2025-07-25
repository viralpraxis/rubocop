# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::LineLength, :config do
  let(:cop_config) { { 'Max' => 80, 'AllowedPatterns' => nil } }

  let(:config) do
    RuboCop::Config.new(
      'Layout/LineLength' => { 'URISchemes' => %w[http https] }.merge(cop_config),
      'Layout/IndentationStyle' => { 'IndentationWidth' => 2 }
    )
  end

  it "registers an offense for a line that's 81 characters wide" do
    maximum_string = '#' * 80
    expect_offense(<<~RUBY, maximum_string: maximum_string)
      #{maximum_string}#
      _{maximum_string}^ Line is too long. [81/80]
    RUBY
    expect(cop.config_to_allow_offenses).to eq(exclude_limit: { 'Max' => 81 })
  end

  it 'highlights excessive characters' do
    maximum_string = '#' * 80
    expect_offense(<<~RUBY, maximum_string: maximum_string)
      #{maximum_string}abc
      _{maximum_string}^^^ Line is too long. [83/80]
    RUBY
  end

  it "accepts a line that's 80 characters wide" do
    expect_no_offenses('#' * 80)
  end

  it 'accepts the first line if it is a shebang line' do
    expect_no_offenses(<<~RUBY)
      #!/System/Library/Frameworks/Ruby.framework/Versions/2.3/usr/bin/ruby --disable-gems

      do_something
    RUBY
  end

  it 'registers an offense for long line before __END__ but not after' do
    maximum_string = '#' * 80
    expect_offense(<<~RUBY, maximum_string: maximum_string)
      #{maximum_string}#{'#' * 70}
      _{maximum_string}#{'^' * 70} Line is too long. [150/80]
      __END__
      #{'#' * 200}
    RUBY
  end

  context 'when line is indented with tabs' do
    let(:cop_config) { { 'Max' => 10, 'AllowedPatterns' => nil } }

    it 'accepts a short line' do
      expect_no_offenses("\t\t\t123")
    end

    it 'registers an offense for a long line' do
      expect_offense(<<~RUBY)
        \t\t\t\t\t\t\t\t\t\t\t\t1
        ^^^^^^^^^^^^^ Line is too long. [25/10]
      RUBY
    end
  end

  context 'when AllowURI option is enabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowURI' => true, 'AllowQualifiedName' => true } }

    context 'and the URL fits within the max allowed characters' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Some documentation comment...
          # See: https://github.com/rubocop/rubocop and then words that are not part of a URL
                                                                                ^^^^^^^^^^^^^ Line is too long. [93/80]
        RUBY
      end
    end

    context 'and all the excessive characters are part of a URL' do
      it 'accepts the line' do
        expect_no_offenses(<<-RUBY)
          # Some documentation comment...
          # See: https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c
        RUBY
      end

      context 'and the URL is wrapped in single quotes' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # See: 'https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c'
          RUBY
        end
      end

      context 'and the URL is wrapped in double quotes' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # See: "https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c"
          RUBY
        end
      end

      context 'and the URL is wrapped in braces' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # See: {https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c}
          RUBY
        end
      end

      context 'and the URL is wrapped in braces with title' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # See: {https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c Optional Title}
          RUBY
        end
      end
    end

    context 'and the excessive characters include a complete URL' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # See: http://google.com/, http://gmail.com/, https://maps.google.com/, http://plus.google.com/
                                                                                ^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [105/80]
        RUBY
      end
    end

    context 'and the excessive characters include part of a URL and another word' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # See: https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c and
                                                                                                   ^^^^ Line is too long. [103/80]
          #   http://google.com/
        RUBY
      end
    end

    context 'and the excessive characters include part of a URL in double quotes' do
      it 'does not include the quote as part of the offense' do
        expect_offense(<<-RUBY)
          # See: "https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c" and
                                                                                                     ^^^^ Line is too long. [105/80]
          #   "http://google.com/"
        RUBY
      end
    end

    context 'and the excessive characters include part of a URL in braces and another word' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # See: {https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c} and
                                                                                                     ^^^^ Line is too long. [105/80]
          #   http://google.com/
        RUBY
      end
    end

    context 'and the excessive characters include part of a URL and trailing whitespace' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # See: https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c#{trailing_whitespace}
                                                                                                   ^ Line is too long. [100/80]
          #   http://google.com/
        RUBY
      end
    end

    context 'with URI starting before or after limit depending on tabs count' do
      let(:cop_config) { { 'Max' => 30, 'AllowURI' => true } }

      it 'registers an offense for the line' do
        expect_offense(<<~RUBY)
          \t\t\t\t# There is some content http://test.com
                                    ^^^^^^^^^^^^^^^^^ Line is too long. [47/30]
        RUBY
      end
    end

    context 'and an error other than URI::InvalidURIError is raised ' \
            'while validating a URI-ish string' do
      let(:cop_config) { { 'Max' => 80, 'AllowURI' => true, 'URISchemes' => %w[LDAP] } }

      it 'does not crash' do
        expect do
          expect_offense(<<~RUBY)
            xxxxxxxxxxxxxxxxxxxxxxxxxxxxzxxxxxxxxxxx = LDAP::DEFAULT_GROUP_UNIQUE_MEMBER_LIST_KEY
                                                                                            ^^^^^ Line is too long. [85/80]
          RUBY
        end.not_to raise_error
      end
    end

    context 'and the URL does not have a http(s) scheme' do
      it 'rejects the line' do
        expect_offense(<<~RUBY)
          #{'x' * 40} = 'otherprotocol://a.very.long.line.which.violates.LineLength/sadf'
          #{' ' * 40}                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [108/80]
        RUBY
      end

      context 'and the scheme has been configured' do
        let(:cop_config) do
          { 'Max' => 80, 'AllowURI' => true, 'URISchemes' => %w[otherprotocol] }
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            #{'x' * 40} = 'otherprotocol://a.very.long.line.which.violates.LineLength/sadf'
          RUBY
        end
      end
    end

    context 'and the URI is assigned' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          #{'x' * 40} = 'https://a.very.long.line.which.violates.LineLength/sadf'
          #{'x' * 40} = "https://a.very.long.line.which.violates.LineLength/sadf"
        RUBY
      end
    end

    context 'and the URI is an argument' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          #{'x' * 40}("https://a.very.long.line.which.violates.LineLength/sadf")
          #{'x' * 40} "https://a.very.long.line.which.violates.LineLength/sadf"
          #{'x' * 40}('https://a.very.long.line.which.violates.LineLength/sadf')
          #{'x' * 40} 'https://a.very.long.line.which.violates.LineLength/sadf'
        RUBY
      end
    end
  end

  context 'when AllowQualifiedName option is enabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowQualifiedName' => true } }

    context 'and the namespace fits within the max allowed characters' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # invoke the normal migration method
          # Should call ActiveRecord::Oracle::SchemaStatements::create_table in the end
                                                                                ^^^^^^^ Line is too long. [87/80]
        RUBY
      end
    end

    context 'and all the excessive characters are part of a qualifed name' do
      it 'accepts the line' do
        expect_no_offenses(<<-RUBY)
          # invoke the normal migration method
          # should end up calling ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table
        RUBY
      end

      context 'and the qualifed name is wrapped in single quotes' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # should end up calling 'ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table'
          RUBY
        end
      end

      context 'and the qualifed name is wrapped in double quotes' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # should end up calling "ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table"
          RUBY
        end
      end

      context 'and the qualifed name is wrapped in braces' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # should end up calling {ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table}
          RUBY
        end
      end
    end

    context 'and the excessive characters include a complete qualifed name' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Invoke the normal migration method, in oracle envs should end up calling ActiveRecord::Oracle::create_table
                                                                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [119/80]
        RUBY
      end
    end

    context 'and the excessive characters include a complete qualifed name when multiple entries are present' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Refer ActiveRecord::Migrations, in oracle envs should end up calling ActiveRecord::Oracle::create_table
                                                                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [115/80]
        RUBY
      end
    end

    context 'and the excessive characters include part of a qualifed name and another word' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Should call ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table and
                                                                                                        ^^^^ Line is too long. [108/80]
          #   ActiveRecord::Example
        RUBY
      end
    end

    context 'and the excessive characters include part of a qualifed name in double quotes' do
      it 'does not include the quote as part of the offense' do
        expect_offense(<<-RUBY)
          # Should call "ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table" and
                                                                                                          ^^^^ Line is too long. [110/80]
          #   "ActiveRecord::Example"
        RUBY
      end
    end

    context 'and the excessive characters include part of a qualifed name in braces and another word' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Should call {ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table} and
                                                                                                          ^^^^ Line is too long. [110/80]
          #   {ActiveRecord::Example}
        RUBY
      end
    end

    context 'and the excessive characters include part of a qualifed name and trailing whitespace' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Should call ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table#{trailing_whitespace}
                                                                                                        ^ Line is too long. [105/80]
          #   http://google.com/
        RUBY
      end
    end

    context 'and the qualifed name is an argument' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          #{'x' * 40}("ActiveRecord::Oracle::SchemaStatements::create_table")
          #{'x' * 40} "ActiveRecord::Oracle::SchemaStatements::create_table"
          #{'x' * 40}('ActiveRecord::Oracle::SchemaStatements::create_table')
          #{'x' * 40} 'ActiveRecord::Oracle::SchemaStatements::create_table'
        RUBY
      end
    end
  end

  context 'when AllowQualifiedName option is not enabled' do
    let(:cop_config) { { 'Max' => 80 } }

    context 'and all the excessive characters are part of a qualifed name' do
      it 'registers an offense' do
        expect_offense(<<-RUBY)
          # invoke the normal migration method
          # should end up calling ActiveRecord::ConnectionAdapters::OracleEnhanced::SchemaStatements::create_table
                                                                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [114/80]
        RUBY
      end
    end
  end

  context 'when AllowedPatterns option is set' do
    let(:cop_config) { { 'Max' => 18, 'AllowedPatterns' => ['^\s*test\s', /^\s*def\s+test_/] } }

    it 'only registers an offense for lines not matching the pattern' do
      expect_offense(<<~RUBY)
        class ExampleTest < TestCase
                          ^^^^^^^^^^ Line is too long. [28/18]
          test 'some really long test description which exceeds length' do
          end
          def test_some_other_long_test_description_which_exceeds_length
          end
        end
      RUBY
    end
  end

  context 'when AllowHeredoc option is enabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowHeredoc' => true } }

    it 'accepts long lines in heredocs' do
      expect_no_offenses(<<~RUBY)
        <<-SQL
          SELECT posts.id, posts.title, users.name FROM posts LEFT JOIN users ON posts.user_id = users.id;
        SQL
      RUBY
    end

    context 'and SplitStrings option is enabled' do
      let(:cop_config) do
        super().merge('SplitStrings' => true)
      end

      it 'does not register an offense' do
        expect_no_offenses(<<~'RUBY')
          <<~MESSAGE
            #{'hello' * 1} #{'world' * 2} #{'hello' * 1} #{'world' * 2} #{'hello' * 1} #{'world' * 2}
          MESSAGE
        RUBY
      end
    end

    context 'when the source has no AST' do
      it 'does not crash' do
        expect { expect_no_offenses('# this results in AST being nil') }.not_to raise_error
      end
    end

    context 'and only certain heredoc delimiters are permitted' do
      let(:cop_config) { { 'Max' => 80, 'AllowHeredoc' => %w[SQL OK], 'AllowedPatterns' => [] } }

      it 'rejects long lines in heredocs with not permitted delimiters' do
        expect_offense(<<-RUBY)
          foo(<<-DOC, <<-SQL, <<-FOO)
            1st offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            #{' ' * 68}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [149/80]
            \#{<<-OK}
              no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            OK
            2nd offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            #{' ' * 68}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [149/80]
          DOC
            no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            \#{<<-XXX}
              no offense (nested inside permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            XXX
            no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          SQL
            3rd offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            #{' ' * 68}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [149/80]
            \#{<<-SQL}
              no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            SQL
            4th offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            #{' ' * 68}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [149/80]
          FOO
        RUBY
      end
    end
  end

  context 'when AllowURI option is disabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowURI' => false } }

    context 'and all the excessive characters are part of a URL' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Lorem ipsum dolar sit amet.
          # See: https://github.com/rubocop/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c
                                                                                ^^^^^^^^^^^^^^^^^^^ Line is too long. [99/80]
        RUBY
      end
    end
  end

  context 'when IgnoreCopDirectives is disabled' do
    let(:cop_config) { { 'Max' => 80, 'IgnoreCopDirectives' => false } }

    context 'and the source is acceptable length' do
      context 'with a trailing RuboCop directive' do
        it 'registers an offense for the line' do
          expect_offense(<<~RUBY)
            #{'a' * 80} # rubocop:disable Layout/SomeCop
            #{' ' * 80}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [113/80]
          RUBY
        end
      end

      context 'with an inline comment' do
        it 'highlights the excess comment' do
          expect_offense(<<~RUBY)
            #{'a' * 80} ###
            #{' ' * 80}^^^^ Line is too long. [84/80]
          RUBY
        end
      end
    end

    context 'and the source is too long and has a trailing cop directive' do
      it 'highlights the excess source and cop directive' do
        expect_offense(<<~RUBY)
          #{'a' * 80} b # rubocop:disable Metrics/AbcSize
          #{' ' * 80}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [116/80]
        RUBY
      end
    end
  end

  context 'when IgnoreCopDirectives is enabled' do
    let(:cop_config) { { 'Max' => 80, 'IgnoreCopDirectives' => true } }

    context 'and the RuboCop directive is excessively long' do
      it 'accepts the line' do
        expect_no_offenses(<<~RUBY)
          # rubocop:disable Metrics/SomeReallyLongMetricNameThatShouldBeMuchShorterAndNeedsANameChange
        RUBY
      end
    end

    context 'and the RuboCop directive causes an excessive line length' do
      it 'accepts the line' do
        expect_no_offenses(<<~RUBY)
          def method_definition_that_is_just_under_the_line_length_limit(foo, bar) # rubocop:disable Metrics/AbcSize
            # complex method
          end
        RUBY
      end

      context 'and has explanatory text' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            def method_definition_that_is_just_under_the_line_length_limit(foo) # rubocop:disable Metrics/AbcSize inherently complex!
              # complex
            end
          RUBY
        end
      end
    end

    context 'and the source is too long' do
      it 'highlights only the non-directive part' do
        expect_offense(<<~RUBY)
          #{'a' * 80}bcd # rubocop:enable Style/ClassVars
          #{' ' * 80}^^^ Line is too long. [83/80]
        RUBY
      end

      context 'and the source contains non-directive # as comment' do
        it 'highlights only the non-directive part' do
          expect_offense(<<~RUBY)
            #{'a' * 70} # bbbbbbbbbbbbbb # rubocop:enable Style/ClassVars'
            #{' ' * 70}          ^^^^^^^ Line is too long. [87/80]
          RUBY
        end
      end

      context 'and the source contains non-directive #s as non-comment' do
        it 'registers an offense for the line' do
          expect_offense(<<-RUBY)
            LARGE_DATA_STRING_PATTERN = %r{\\A([A-Za-z0-9+/#]*={0,2})#([A-Za-z0-9+/#]*={0,2})#([A-Za-z0-9+/#]*={0,2})\\z} # rubocop:disable Style/ClassVars
            #{' ' * 68}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [119/80]
          RUBY
        end
      end
    end
  end

  context 'affecting by IndentationWidth from Layout\Tab' do
    shared_examples 'with tabs indentation' do
      it "registers an offense for a line that's including 2 tab with size 2 " \
         'and 28 other characters' do
        expect_offense(<<~RUBY)
          \t\t#{'#' * 28}a
              #{' ' * 24}^^^ Line is too long. [33/30]
        RUBY
        expect(cop.config_to_allow_offenses).to eq(exclude_limit: { 'Max' => 33 })
      end

      it "accepts a line that's including 1 tab with size 2 and 28 other characters" do
        expect_no_offenses("\t#{'#' * 28}")
      end
    end

    context 'without AllowURI option' do
      let(:config) do
        RuboCop::Config.new(
          'Layout/IndentationWidth' => {
            'Width' => 1
          },
          'Layout/IndentationStyle' => {
            'Enabled' => false,
            'IndentationWidth' => 2
          },
          'Layout/LineLength' => {
            'Max' => 30
          }
        )
      end

      it_behaves_like 'with tabs indentation'
    end

    context 'with AllowURI option' do
      let(:config) do
        RuboCop::Config.new(
          'Layout/IndentationWidth' => {
            'Width' => 1
          },
          'Layout/IndentationStyle' => {
            'Enabled' => false,
            'IndentationWidth' => 2
          },
          'Layout/LineLength' => {
            'Max' => 30,
            'AllowURI' => true
          }
        )
      end

      it_behaves_like 'with tabs indentation'

      it "accepts a line that's including URI" do
        expect_no_offenses("\t\t# https://github.com/rubocop/rubocop")
      end

      it "accepts a line that's including URI and exceeds by 1 char" do
        expect_no_offenses("\t\t# https://github.com/ruboco")
      end

      it "accepts a line that's including URI with text" do
        expect_no_offenses("\t\t# See https://github.com/rubocop/rubocop")
      end

      it "accepts a line that's including URI in quotes with text" do
        expect_no_offenses("\t\t# See 'https://github.com/rubocop/rubocop'")
      end

      it 'registers the line which looks like YARD comment' do
        expect_offense(<<-RUBY)
          \texpect(some_exception_variable) {|e| e.url.should == 'http://host/path'}
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [83/30]
        RUBY
      end
    end
  end

  context 'autocorrection' do
    let(:split_strings) { true }
    let(:cop_config) do
      {
        'Max' => 40,
        'AllowedPatterns' => nil,
        'AutoCorrect' => true,
        'SplitStrings' => split_strings
      }
    end

    context 'string' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            'aaaaaaaaaaaaaaaaaaa'
          RUBY
        end

        it 'does not add any offenses with interpolation' do
          expect_no_offenses(<<~'RUBY')
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#{bbbbb}'
          RUBY
        end
      end

      context 'when over limit' do
        context 'when SplitStrings: true' do
          let(:split_strings) { true }

          it 'breaks the string at the limit' do
            expect_offense(<<~RUBY)
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbb'
                                                      ^^^ Line is too long. [43/40]
            RUBY

            expect_correction(<<~'RUBY')
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
              'bbbbb'
            RUBY
          end

          context 'when AllowHeredoc: false' do
            let(:cop_config) { super().merge('AllowHeredoc' => false) }

            context 'with multiple string interpolations' do
              it 'registers an offense and autocorrects' do
                expect_offense(<<~'RUBY')
                  <<~MESSAGE
                    #{'hello' * 1} #{'world' * 2} #{'hello' * 1}
                                                          ^^^^^^ Line is too long. [46/40]
                  MESSAGE
                RUBY

                expect_correction(<<~'RUBY')
                  <<~MESSAGE
                    #{'hello' * 1} #{'world' * 2} #{'he' \
                  'llo' * 1}
                  MESSAGE
                RUBY
              end
            end
          end

          context 'when the string straddles after the limit' do
            it 'registers an offense but does not correct' do
              expect_offense(<<~RUBY)
                foo
                                                     'aaaa'
                                                        ^^^ Line is too long. [43/40]
              RUBY

              expect_no_corrections
            end
          end

          context 'when the string starts after the limit' do
            it 'registers an offense but does not correct' do
              expect_offense(<<~RUBY)
                foo
                                                        'aaaa'
                                                        ^^^^^^ Line is too long. [46/40]
              RUBY

              expect_no_corrections
            end
          end

          context 'when there is already a continuation' do
            it 'breaks the string at the limit' do
              expect_offense(<<~'RUBY')
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcccccccccccc'
                                                        ^^^^^^^^^^ Line is too long. [50/40]
              RUBY

              expect_correction(<<~'RUBY')
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' \
                'cccccccccccc'
              RUBY
            end
          end

          context 'when the string is not at the start of the source' do
            it 'breaks the string at the limit' do
              expect_offense(<<~RUBY)
                x = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbb'
                                                        ^^^ Line is too long. [43/40]
              RUBY

              expect_correction(<<~'RUBY', loop: false)
                x = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
                'bbbbb'
              RUBY
            end

            context 'with spaces' do
              it 'breaks the string at the last space' do
                expect_offense(<<~RUBY)
                  x = 'aaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbb'
                                                          ^^^^ Line is too long. [44/40]
                RUBY

                expect_correction(<<~'RUBY', loop: false)
                  x = 'aaaaaaaaaaaaaaaaaaaaaa ' \
                  'bbbbbbbbbbbbbbb'
                RUBY
              end
            end

            context 'with escape characters' do
              it 'breaks the string at the last space' do
                expect_offense(<<~'RUBY')
                  x = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nbbbbbbbbbb'
                                                          ^^^^^^^^^ Line is too long. [49/40]
                RUBY

                expect_correction(<<~'RUBY', loop: false)
                  x = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
                  '\nbbbbbbbbbb'
                RUBY
              end
            end
          end

          context 'inside a hash' do
            it 'breaks the hash not the string' do
              expect_offense(<<~RUBY)
                { x: 'aaaa', y: 'bbbbbbbbbbbbbbbbbbbbbbbbbbb', z: 'cccccccccccccccccccccccccccccccccccccccccc' }
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [96/40]
              RUBY

              expect_correction(<<~RUBY)
                { x: 'aaaa',#{' '}
                y: 'bbbbbbbbbbbbbbbbbbbbbbbbbbb', z: 'cccccccccccccccccccccccccccccccccccccccccc' }
              RUBY
            end
          end

          context 'due to a comment' do
            it 'registers an offense but does not correct' do
              expect_offense(<<~RUBY)
                'aaaaaaaaaaaaaaaaaaaaa' # this comment makes the line too long
                                                        ^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [62/40]
              RUBY

              expect_no_corrections
            end
          end

          context 'when there is a space in the string' do
            it 'breaks the string at the space' do
              expect_offense(<<~RUBY)
                'aaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbb'
                                                        ^^^^^^ Line is too long. [46/40]
              RUBY

              expect_correction(<<~'RUBY')
                'aaaaaaaaaaaaaaaaaaaaaaaaa ' \
                'bbbbbbbbbbbbbbbbbb'
              RUBY
            end
          end

          context 'when there are multiple spaces in the string' do
            it 'breaks the string at the last space before the limit' do
              expect_offense(<<~RUBY)
                'aaaaaaaaaaaaaaaaaaaaaaaaa bbbbb ccccccccc dddddddddddddddddddddd eeeeeeeeeeee'
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [79/40]
              RUBY

              expect_correction(<<~'RUBY')
                'aaaaaaaaaaaaaaaaaaaaaaaaa bbbbb ' \
                'ccccccccc dddddddddddddddddddddd ' \
                'eeeeeeeeeeee'
              RUBY
            end
          end

          context 'when there is an escape character at the limit' do
            it 'breaks the string before the escape character' do
              expect_offense(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nbbbb"
                                                        ^^^ Line is too long. [43/40]
              RUBY

              expect_correction(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                "\nbbbb"
              RUBY
            end
          end

          context 'when there is an \u escape character at the limit' do
            it 'breaks the string before the escape character' do
              expect_offense(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\u0061bbbb"
                                                        ^^^^^^ Line is too long. [46/40]
              RUBY

              expect_correction(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                "\u0061bbbb"
              RUBY
            end
          end

          context 'when there is an \x escape character at the limit' do
            it 'breaks the string before the escape character' do
              expect_offense(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\x61bbbb"
                                                        ^^ Line is too long. [42/40]
              RUBY

              expect_correction(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                "\x61bbbb"
              RUBY
            end
          end

          context 'when there is a multibyte character at the limit' do
            it 'breaks the string at the limit' do
              expect_offense(<<~RUBY)
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaあbbbbb"
                                                        ^^^^ Line is too long. [44/40]
              RUBY

              expect_correction(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                "あbbbbb"
              RUBY
            end
          end

          context 'when the string is inside a %{}' do
            it 'registers an offense but does not correct' do
              expect_offense(<<~RUBY)
                %{aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}
                                                        ^^^^ Line is too long. [44/40]
              RUBY

              expect_no_corrections
            end
          end

          %i[%q %Q %i %I %w %W].each do |macro|
            context "when the string is inside a #{macro}" do
              it 'registers an offense but does not correct' do
                expect_offense(<<~RUBY, macro: macro)
                  %{macro}[aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa]
                  _{macro}                                      ^^^^^ Line is too long. [45/40]
                RUBY

                expect_no_corrections
              end
            end
          end

          context 'when the string is inside a heredoc' do
            it 'registers an offense but does not correct' do
              expect_offense(<<~RUBY)
                <<~STR
                  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                                                        ^^^ Line is too long. [43/40]
                STR
              RUBY

              expect_no_corrections
            end
          end

          context 'with interpolation' do
            it 'breaks the string before the interpolation' do
              expect_offense(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#{bbbb}"
                                                        ^^^^ Line is too long. [44/40]
              RUBY

              expect_correction(<<~'RUBY')
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                "#{bbbb}"
              RUBY
            end

            context 'when the interpolation is before the limit' do
              it 'breaks the string at the limit' do
                expect_offense(<<~'RUBY')
                  "#{bbbb}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                                                          ^^^^^^^^^^^^^^ Line is too long. [54/40]
                RUBY

                expect_correction(<<~'RUBY')
                  "#{bbbb}aaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                  "aaaaaaaaaaaaaaaa"
                RUBY
              end
            end

            context 'when the interpolation comes after the limit' do
              it 'breaks the string but not the interpolation' do
                expect_offense(<<~'RUBY')
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#{bbbb}"
                                                          ^^^^^^^^^^^^^^ Line is too long. [54/40]
                RUBY

                expect_correction(<<~'RUBY')
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                  "aaaaaaaaa#{bbbb}"
                RUBY
              end
            end

            context 'when the interpolation is not on the first line' do
              it 'registers an offense and corrects' do
                expect_offense(<<~'RUBY')
                  a_long_named_method_call
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#{bbbbbbbbb}"
                                                          ^^^^^^^^^^ Line is too long. [50/40]
                RUBY

                expect_correction(<<~'RUBY')
                  a_long_named_method_call
                  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
                  "#{bbbbbbbbb}"
                RUBY
              end
            end

            context 'when the entire string is interpolation' do
              it 'registers an offense but does not correct' do
                expect_offense(<<~'RUBY')
                  "#{aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
                                                          ^^^^^^^^^^^^^^ Line is too long. [54/40]
                RUBY

                expect_no_corrections
              end
            end

            context 'with multiple interpolations' do
              it 'breaks the string where appropriate' do
                expect_offense(<<~'RUBY')
                  "#{aaaaa}bbbbbbb#{cccccc}ddddddddddddddddddddd#{eeeeeeeeeeee}"
                                                          ^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [62/40]
                RUBY

                expect_correction(<<~'RUBY')
                  "#{aaaaa}bbbbbbb#{cccccc}dddddddddddd" \
                  "ddddddddd#{eeeeeeeeeeee}"
                RUBY
              end
            end

            context 'nested interpolation' do
              it 'breaks the string before the outer interpolation' do
                expect_offense(<<~'RUBY')
                  "aaaaaaaaaaaaa#{"#{bbbbbbbbbbbbbbbbbbbbbbbb}"}"
                                                          ^^^^^^^ Line is too long. [47/40]
                RUBY

                expect_correction(<<~'RUBY')
                  "aaaaaaaaaaaaa" \
                  "#{"#{bbbbbbbbbbbbbbbbbbbbbbbb}"}"
                RUBY
              end
            end
          end
        end

        context 'when SplitStrings: false' do
          let(:split_strings) { false }

          it 'registers an offense but does not correct' do
            expect_offense(<<~RUBY)
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                                                      ^^^ Line is too long. [43/40]
            RUBY

            expect_no_corrections
          end
        end
      end
    end

    context 'hash' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            {foo: 1, bar: "2"}
          RUBY
        end
      end

      context 'when over limit because of a comment' do
        it 'adds an offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            { # supersupersupersupersupersupersupersupersupersupersupersuperlongcomment
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [75/40]
              baz: "10000",
              bar: "10000"}
          RUBY

          expect_no_corrections
        end
      end

      context 'when over limit and already on multiple lines long key' do
        it 'adds an offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            {supersupersupersupersupersupersupersupersupersupersupersuperfirstarg: 10,
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [74/40]
              baz: "10000",
              bar: "10000"}
          RUBY

          expect_no_corrections
        end
      end

      context 'when over limit and keys already on multiple lines' do
        it 'adds an offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            {
              baz0: "10000",
              baz1: "10000",
              baz2: "10000", baz2: "10000", baz3: "10000", baz4: "10000",
                                                    ^^^^^^^^^^^^^^^^^^^^^ Line is too long. [61/40]
              bar: "10000"}
          RUBY

          expect_no_corrections
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            {abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [75/40]
          RUBY

          expect_correction(<<~RUBY)
            {abc: "100000", def: "100000",#{trailing_whitespace}
            ghi: "100000", jkl: "100000", mno: "100000"}
          RUBY
        end
      end

      context 'when over limit rocket' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            {"abc" => "100000", "def" => "100000", "casd" => "100000", "asdf" => "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [78/40]
          RUBY

          expect_correction(<<~RUBY)
            {"abc" => "100000", "def" => "100000",#{trailing_whitespace}
            "casd" => "100000", "asdf" => "100000"}
          RUBY
        end
      end

      context 'when over limit rocket symbol' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            {:abc => "100000", :asd => "100000", :asd => "100000", :fds => "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [72/40]
          RUBY

          expect_correction(<<~RUBY)
            {:abc => "100000", :asd => "100000",#{trailing_whitespace}
            :asd => "100000", :fds => "100000"}
          RUBY
        end
      end

      context 'when nested hashes on same line' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            {abc: "100000", def: "100000", ghi: {abc: "100000"}, jkl: "100000", mno: "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [82/40]
          RUBY

          expect_correction(<<~RUBY)
            {abc: "100000", def: "100000",#{trailing_whitespace}
            ghi: {abc: "100000"}, jkl: "100000", mno: "100000"}
          RUBY
        end
      end

      context 'when hash in method call' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            get(
              :index,
              params: {driver_id: driver.id, from_date: "2017-08-18T15:09:04.000Z", to_date: "2017-09-19T15:09:04.000Z"},
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [109/40]
              xhr: true)
          RUBY

          expect_correction(<<~RUBY)
            get(
              :index,
              params: {driver_id: driver.id,#{trailing_whitespace}
            from_date: "2017-08-18T15:09:04.000Z", to_date: "2017-09-19T15:09:04.000Z"},
              xhr: true)
          RUBY
        end
      end
    end

    context 'method definition' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            def foo(foo: 1, bar: "2"); end
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            def foo(abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [82/40]
            end
          RUBY

          expect_correction(<<~RUBY)
            def foo(abc: "100000", def: "100000",#{trailing_whitespace}
            ghi: "100000", jkl: "100000", mno: "100000")
            end
          RUBY
        end
      end
    end

    context 'class method definition' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            def self.foo(foo: 1, bar: "2"); end
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            def self.foo(abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [87/40]
            end
          RUBY

          expect_correction(<<~RUBY)
            def self.foo(abc: "100000",#{trailing_whitespace}
            def: "100000", ghi: "100000", jkl: "100000", mno: "100000")
            end
          RUBY
        end
      end
    end

    context 'method call' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            foo(foo: 1, bar: "2")
          RUBY
        end
      end

      context 'when two together' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            def baz(bar)
              foo(shipment, actionable_delivery) &&
                bar(shipment, actionable_delivery)
            end
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            foo(abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [78/40]
          RUBY

          expect_correction(<<~RUBY)
            foo(abc: "100000", def: "100000",\s
            ghi: "100000", jkl: "100000", mno: "100000")
          RUBY
        end
      end

      context 'when unparenthesized' do
        context 'when there is one argument' do
          it 'does not autocorrect' do
            expect_offense(<<~RUBY)
              method_call xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                                                      ^^ Line is too long. [42/40]
            RUBY

            expect_no_corrections
          end
        end

        context 'when there are multiple arguments' do
          it 'splits the line after the first element' do
            args = 'x' * 28
            expect_offense(<<~RUBY, args: args)
              method_call #{args}, abc
                          _{args}^^^^^ Line is too long. [45/40]
            RUBY

            expect_correction(<<~RUBY, loop: false)
              method_call #{args},#{trailing_whitespace}
              abc
            RUBY
          end
        end
      end

      context 'when call with hash on same line' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            foo(abc: "100000", def: "100000", ghi: {abc: "100000"}, jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [85/40]
          RUBY

          expect_correction(<<~RUBY)
            foo(abc: "100000", def: "100000",\s
            ghi: {abc: "100000"}, jkl: "100000", mno: "100000")
          RUBY
        end
      end

      context 'with a hash with a too long first item' do
        context 'when parenthesized' do
          it 'corrects' do
            expect_offense(<<~RUBY)
              foo(abc: '10000000000000000000000000000000000000000000000000000', def: '1000')
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [78/40]
            RUBY

            expect_correction(<<~RUBY)
              foo(
              abc: '10000000000000000000000000000000000000000000000000000', def: '1000')
            RUBY
          end
        end

        context 'when the hash is parenthesized' do
          it 'corrects' do
            expect_offense(<<~RUBY)
              foo({ abc: '10000000000000000000000000000000000000000000000000000', def: '1000' })
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [82/40]
            RUBY

            expect_correction(<<~RUBY)
              foo({#{trailing_whitespace}
              abc: '10000000000000000000000000000000000000000000000000000', def: '1000' })
            RUBY
          end
        end

        context 'when not parenthesized' do
          context 'when there is only one element' do
            it 'does not autocorrect' do
              expect_offense(<<~RUBY)
                foo abc: '10000000000000000000000000000000000000000000000000000'
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [64/40]
              RUBY

              expect_no_corrections
            end
          end

          context 'when there are multiple elements' do
            it 'moves the 2nd element to a new line' do
              expect_offense(<<~RUBY)
                foo abc: '10000000000000000000000000000000000000000000000000000', ghi: '1000'
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [77/40]
              RUBY

              expect_correction(<<~RUBY, loop: false)
                foo abc: '10000000000000000000000000000000000000000000000000000',#{trailing_whitespace}
                ghi: '1000'
              RUBY
            end
          end

          context 'when on multiple lines' do
            it 'does not correct' do
              expect_offense(<<~RUBY)
                foo abc: '10000000000000000000000000000000000000000000000000000',
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [65/40]
                    ghi: '1000'
              RUBY

              expect_no_corrections
            end
          end
        end
      end

      context 'when two method calls' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            get(1000000, 30000, foo(44440000, 30000, 39999, 19929120312093))
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [64/40]
          RUBY

          expect_correction(<<~RUBY)
            get(1000000, 30000,\s
            foo(44440000, 30000, 39999, 19929120312093))
          RUBY
        end
      end

      context 'when nested method calls allows outer to get broken up first' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            get(1000000,
            foo(44440000, 30000, 39999, 1992), foo(44440000, 30000, 39999, 12093))
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          RUBY

          expect_no_corrections
        end
      end

      context 'with long argument list' do
        it 'registers an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            attr_reader :first_name, :last_name, :email, :username, :country, :state, :city, :postal_code
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [93/40]
          RUBY

          expect_correction(<<~RUBY)
            attr_reader :first_name, :last_name,#{trailing_whitespace}
            :email, :username, :country, :state, :city, :postal_code
          RUBY
        end
      end

      context 'with a heredoc argument' do
        it 'does not break up the line' do
          args = 'x' * 25
          expect_offense(<<~RUBY, args: args)
            foo(<<~STRING, #{args}xxx)
                           _{args}^^^^ Line is too long. [44/40]
            STRING
          RUBY

          expect_no_corrections
        end

        it 'does not break up the line when parentheses are omitted' do
          args = 'x' * 25
          expect_offense(<<~RUBY, args: args)
            foo <<~STRING, #{args}xxx
                           _{args}^^^ Line is too long. [43/40]
            STRING
          RUBY

          expect_no_corrections
        end

        it 'does not break up the line when a heredoc is used as the first element of an array' do
          expect_offense(<<~RUBY)
            [<<~STRING, { key1: value1, key2: value2 }]
                                                    ^^^ Line is too long. [43/40]
            STRING
          RUBY

          expect_no_corrections
        end

        context 'and other arguments before the heredoc' do
          it 'can break up the line before the heredoc argument' do
            args = 'x' * 20
            expect_offense(<<~RUBY, args: args)
              foo(abc, <<~STRING, #{args}xxx)
                                  _{args}^^^^ Line is too long. [44/40]
              STRING
            RUBY

            expect_correction(<<~RUBY)
              foo(abc,#{trailing_whitespace}
              <<~STRING, #{args}xxx)
              STRING
            RUBY
          end
        end

        context 'and the heredoc is after the line should split' do
          it 'can break up the line before the heredoc argument' do
            args = 'x' * 34
            expect_offense(<<~RUBY, args: args)
              foo(#{args}, <<~STRING)
                  _{args}  ^^^^^^^^^^ Line is too long. [50/40]
              STRING
            RUBY

            expect_correction(<<~RUBY)
              foo(#{args},#{trailing_whitespace}
              <<~STRING)
              STRING
            RUBY
          end
        end
      end
    end

    context 'safe navigation method call' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            foo&.bar(foo: 1, bar: "2")
          RUBY
        end
      end

      context 'when two together' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            def baz(bar)
              foo&.bar(shipment, actionable) &&
                bar(shipment, actionable)
            end
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            foo&.bar(abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [83/40]
          RUBY

          expect_correction(<<~RUBY)
            foo&.bar(abc: "100000", def: "100000",\s
            ghi: "100000", jkl: "100000", mno: "100000")
          RUBY
        end
      end

      context 'when unparenthesized' do
        context 'when there is one argument' do
          it 'does not autocorrect' do
            expect_offense(<<~RUBY)
              foo&.bar xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                                                      ^^ Line is too long. [42/40]
            RUBY

            expect_no_corrections
          end
        end

        context 'when there are multiple arguments' do
          it 'splits the line after the first element' do
            args = 'x' * 28
            expect_offense(<<~RUBY, args: args)
              foo&.bar #{args}, abc
                       _{args}   ^^ Line is too long. [42/40]
            RUBY

            expect_correction(<<~RUBY, loop: false)
              foo&.bar #{args},#{trailing_whitespace}
              abc
            RUBY
          end
        end
      end

      context 'when call with hash on same line' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            foo&.bar(abc: "100000", def: "100000", ghi: {abc: "100000"}, jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [90/40]
          RUBY

          expect_correction(<<~RUBY)
            foo&.bar(abc: "100000", def: "100000",\s
            ghi: {abc: "100000"}, jkl: "100000", mno: "100000")
          RUBY
        end
      end

      context 'with a hash with a too long first item' do
        context 'when parenthesized' do
          it 'corrects' do
            expect_offense(<<~RUBY)
              foo&.bar(abc: '10000000000000000000000000000000000000000000000000000', def: '1000')
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [83/40]
            RUBY

            expect_correction(<<~RUBY)
              foo&.bar(
              abc: '10000000000000000000000000000000000000000000000000000', def: '1000')
            RUBY
          end
        end

        context 'when the hash is parenthesized' do
          it 'corrects' do
            expect_offense(<<~RUBY)
              foo&.bar({ abc: '10000000000000000000000000000000000000000000000000000', def: '1000' })
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [87/40]
            RUBY

            expect_correction(<<~RUBY)
              foo&.bar({#{trailing_whitespace}
              abc: '10000000000000000000000000000000000000000000000000000', def: '1000' })
            RUBY
          end
        end

        context 'when not parenthesized' do
          context 'when there is only one element' do
            it 'does not autocorrect' do
              expect_offense(<<~RUBY)
                foo&.bar abc: '10000000000000000000000000000000000000000000000000000'
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [69/40]
              RUBY

              expect_no_corrections
            end
          end

          context 'when there are multiple elements' do
            it 'breaks after the method call' do
              expect_offense(<<~RUBY)
                foo&.bar abc: '10000000000000000000000000000000000000000000000000000', ghi: '1000'
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [82/40]
              RUBY

              expect_correction(<<~RUBY, loop: false)
                foo&.bar abc: '10000000000000000000000000000000000000000000000000000',#{trailing_whitespace}
                ghi: '1000'
              RUBY
            end
          end

          context 'when on multiple lines' do
            it 'does not correct' do
              expect_offense(<<~RUBY)
                foo&.bar abc: '10000000000000000000000000000000000000000000000000000',
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
                    ghi: '1000'
              RUBY

              expect_no_corrections
            end
          end
        end
      end

      context 'when two method calls' do
        context 'when the inner uses safe navigation' do
          it 'adds an offense only to outer and autocorrects it' do
            expect_offense(<<~RUBY)
              get(1000000, 30000, foo&.bar(44440000, 30000, 39999, 19929120312093))
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [69/40]
            RUBY

            expect_correction(<<~RUBY)
              get(1000000, 30000,\s
              foo&.bar(44440000, 30000, 39999, 19929120312093))
            RUBY
          end
        end

        context 'when the outer uses safe navigation' do
          it 'adds an offense only to outer and autocorrects it' do
            expect_offense(<<~RUBY)
              get&.bar(1000000, 30000, foo(44440000, 30000, 39999, 19929120312093))
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [69/40]
            RUBY

            expect_correction(<<~RUBY)
              get&.bar(1000000, 30000,\s
              foo(44440000, 30000, 39999, 19929120312093))
            RUBY
          end
        end

        context 'when both use safe navigation' do
          it 'adds an offense only to outer and autocorrects it' do
            expect_offense(<<~RUBY)
              get&.bar(1000000, 30000, foo&.baz(44440000, 30000, 39999, 19929120312093))
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [74/40]
            RUBY

            expect_correction(<<~RUBY)
              get&.bar(1000000, 30000,\s
              foo&.baz(44440000, 30000, 39999, 19929120312093))
            RUBY
          end
        end
      end

      context 'when nested method calls allows outer to get broken up first' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            get(1000000,
            foo&.bar(44440000, 30000, 39999, 1992), foo&.baz(44440000, 30000, 39999, 12093))
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [80/40]
          RUBY

          expect_no_corrections
        end
      end

      context 'when nested method calls with safe navigation allows outer to get broken up first' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            get&.foo(1000000,
            foo&.bar(44440000, 30000, 39999, 1992), foo&.baz(44440000, 30000, 39999, 12093))
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [80/40]
          RUBY

          expect_no_corrections
        end
      end

      context 'with long argument list' do
        it 'registers an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            foo&.bar :first_name, :last_name, :email, :username, :country, :state, :city, :postal_code
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [90/40]
          RUBY

          expect_correction(<<~RUBY)
            foo&.bar :first_name, :last_name,#{trailing_whitespace}
            :email, :username, :country, :state, :city, :postal_code
          RUBY
        end
      end

      context 'with a heredoc argument' do
        it 'does not break up the line' do
          args = 'x' * 20
          expect_offense(<<~RUBY, args: args)
            foo&.bar(<<~STRING, #{args}xxx)
                                _{args}^^^^ Line is too long. [44/40]
            STRING
          RUBY

          expect_no_corrections
        end

        it 'does not break up the line when parentheses are omitted' do
          args = 'x' * 20
          expect_offense(<<~RUBY, args: args)
            foo&.bar <<~STRING, #{args}xxx
                                _{args}^^^ Line is too long. [43/40]
            STRING
          RUBY

          expect_no_corrections
        end

        context 'and other arguments before the heredoc' do
          it 'can break up the line before the heredoc argument' do
            args = 'x' * 15
            expect_offense(<<~RUBY, args: args)
              foo&.bar(abc, <<~STRING, #{args}xxx)
                                       _{args}^^^^ Line is too long. [44/40]
              STRING
            RUBY

            expect_correction(<<~RUBY)
              foo&.bar(abc,#{trailing_whitespace}
              <<~STRING, #{args}xxx)
              STRING
            RUBY
          end
        end

        context 'and the heredoc is after the line should split' do
          it 'can break up the line before the heredoc argument' do
            args = 'x' * 29
            expect_offense(<<~RUBY, args: args)
              foo&.bar(#{args}, <<~STRING)
                       _{args}  ^^^^^^^^^^ Line is too long. [50/40]
              STRING
            RUBY

            expect_correction(<<~RUBY)
              foo&.bar(#{args},#{trailing_whitespace}
              <<~STRING)
              STRING
            RUBY
          end
        end
      end
    end

    context 'array' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            [1, "2"]
          RUBY
        end
      end

      context 'when already on two lines' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            [1, "2",
             "3"]
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            ["1111", "100000", "100000", "100000", "100000", "100000"]
                                                    ^^^^^^^^^^^^^^^^^^ Line is too long. [58/40]
          RUBY

          expect_correction(<<~RUBY)
            ["1111", "100000", "100000", "100000",\s
            "100000", "100000"]
          RUBY
        end
      end

      context 'when has inside array' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            ["1111", "100000", "100000", "100000", {abc: "100000", b: "2"}, "100000", "100000"]
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [83/40]
          RUBY

          expect_correction(<<~RUBY)
            ["1111", "100000", "100000", "100000",\s
            {abc: "100000", b: "2"}, "100000", "100000"]
          RUBY
        end
      end

      context 'when two arrays on two lines allows outer to get broken first' do
        it 'adds an offense only to inner and does not autocorrect it' do
          expect_offense(<<~RUBY)
            [1000000, 3912312312999,
              [44440000, 3912312312999, 3912312312999, 1992912031231232131312093],
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
            100, 100]
          RUBY

          expect_no_corrections
        end
      end
    end

    context 'breakable collection' do
      context 'method call inside a hash' do
        it 'breaks the hash, not the method' do
          expect_offense(<<~RUBY)
            { foo: 1234567890, bar: method_call(x, y, z) }
                                                    ^^^^^^ Line is too long. [46/40]
          RUBY

          expect_correction(<<~RUBY)
            { foo: 1234567890,#{trailing_whitespace}
            bar: method_call(x, y, z) }
          RUBY
        end
      end

      context 'safe navigation method call inside a hash' do
        it 'breaks the hash, not the method' do
          expect_offense(<<~RUBY)
            { foo: 1234567890, bar: foo&.bar(x, y, z) }
                                                    ^^^ Line is too long. [43/40]
          RUBY

          expect_correction(<<~RUBY)
            { foo: 1234567890,#{trailing_whitespace}
            bar: foo&.bar(x, y, z) }
          RUBY
        end
      end
    end

    context 'no breakable collections' do
      it 'adds an offense and does not autocorrect it' do
        expect_offense(<<~RUBY)
          10000003912312312999
            # 444400003912312312999391231231299919929120312312321313120933333333
                                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          456
        RUBY

        expect_no_corrections
      end
    end

    context 'long blocks' do
      context 'braces' do
        it 'adds an offense and does correct it' do
          expect_offense(<<~RUBY)
            foo.select { |bar| 4444000039123123129993912312312999199291203123123 }
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          RUBY

          expect_correction(<<~RUBY)
            foo.select { |bar|
             4444000039123123129993912312312999199291203123123 }
          RUBY
        end
      end

      context 'do/end' do
        it 'adds an offense for block with arguments and does correct it' do
          expect_offense(<<~RUBY)
            foo.select do |bar| 4444000039123123129993912312312999199291203123 end
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          RUBY

          expect_correction(<<~RUBY)
            foo.select do |bar|
             4444000039123123129993912312312999199291203123 end
          RUBY
        end

        it 'adds an offense for block without arguments and does correct it' do
          expect_offense(<<~RUBY)
            foo.select do 4444000039123123129993912312312999199291203123 end
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [64/40]
          RUBY

          expect_correction(<<~RUBY)
            foo.select do
             4444000039123123129993912312312999199291203123 end
          RUBY
        end
      end

      context 'let block' do
        it 'adds an offense and does correct it' do
          expect_offense(<<~RUBY)
            let(:foobar) { BazBazBaz::BazBazBaz::BazBazBaz::BazBazBaz.baz(baz12) }
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          RUBY

          expect_correction(<<~RUBY)
            let(:foobar) {
             BazBazBaz::BazBazBaz::BazBazBaz::BazBazBaz.baz(baz12) }
          RUBY
        end
      end

      context 'no spaces' do
        it 'adds an offense and does correct it' do
          expect_offense(<<~RUBY)
            let(:foobar){BazBazBaz::BazBazBaz::BazBazBaz::BazBazBaz.baz(baz12345)}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          RUBY

          expect_correction(<<~RUBY)
            let(:foobar){
            BazBazBaz::BazBazBaz::BazBazBaz::BazBazBaz.baz(baz12345)}
          RUBY
        end
      end

      context 'lambda syntax' do
        context 'when argument is enclosed in parentheses' do
          it 'registers an offense and corrects' do
            expect_offense(<<~RUBY)
              ->(x) { fooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo }
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
            RUBY

            expect_correction(<<~RUBY)
              ->(x) {
               fooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo }
            RUBY
          end
        end

        context 'when argument is not enclosed in parentheses' do
          it 'registers an offense and corrects' do
            expect_offense(<<~RUBY)
              -> x { foooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo }
                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
            RUBY

            expect_correction(<<~RUBY)
              -> x {
               foooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo }
            RUBY
          end
        end
      end

      context 'Ruby 3.4', :ruby34 do
        it 'adds an offense for {} block does correct it' do
          expect_offense(<<~RUBY)
            foo.select { it + 4444000039123123129993912312312999199291203123123 }
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [69/40]
          RUBY

          expect_correction(<<~RUBY)
            foo.select {
             it + 4444000039123123129993912312312999199291203123123 }
          RUBY
        end

        it 'adds an offense for do-end block and does correct it' do
          expect_offense(<<~RUBY)
            foo.select do it + 4444000039123123129993912312312999199291203123 end
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [69/40]
          RUBY

          expect_correction(<<~RUBY)
            foo.select do
             it + 4444000039123123129993912312312999199291203123 end
          RUBY
        end
      end
    end

    context 'semicolon' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            {foo: 1, bar: "2"}; a = 4 + 5
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds offense and autocorrects it by breaking the semicolon before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}; a = 400000000000 + 500000000000000
                                                    ^^^^^^^^^^^^^^ Line is too long. [54/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"};
             a = 400000000000 + 500000000000000
          RUBY
        end
      end

      context 'when over limit and semicolon at end of line' do
        it 'adds offense and autocorrects it by breaking the first semicolon before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}; a = 400000000000 + 500000000000000;
                                                    ^^^^^^^^^^^^^^^ Line is too long. [55/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"};
             a = 400000000000 + 500000000000000;
          RUBY
        end
      end

      context 'when over limit and many spaces around semicolon' do
        it 'adds offense and autocorrects it by breaking the semicolon before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}  ;   a = 400000000000 + 500000000000000
                                                    ^^^^^^^^^^^^^^^^^^ Line is too long. [58/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"}  ;
               a = 400000000000 + 500000000000000
          RUBY
        end
      end

      context 'when over limit and many semicolons' do
        it 'adds offense and autocorrects it by breaking the semicolon before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}  ;;; a = 400000000000 + 500000000000000
                                                    ^^^^^^^^^^^^^^^^^^ Line is too long. [58/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"}  ;;;
             a = 400000000000 + 500000000000000
          RUBY
        end
      end

      context 'when over limit and one semicolon at the end' do
        it 'adds offense and does not autocorrect before the hash' do
          expect_offense(<<~RUBY)
            a = 400000000000 + 500000000000000000000;
                                                    ^ Line is too long. [41/40]
          RUBY

          expect_no_corrections
        end
      end

      context 'when over limit and many semicolons at the end' do
        it 'adds offense and does not autocorrect before the hash' do
          expect_offense(<<~RUBY)
            a = 400000000000 + 500000000000000000000;;;;;;;
                                                    ^^^^^^^ Line is too long. [47/40]
          RUBY

          expect_no_corrections
        end
      end

      context 'semicolon inside string literal' do
        it 'adds offense and autocorrects elsewhere' do
          expect_offense(<<~RUBY)
            FooBar.new(baz: 30, bat: 'publisher_group:123;publisher:456;s:123')
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [67/40]
          RUBY

          expect_correction(<<~RUBY)
            FooBar.new(baz: 30,\s
            bat: 'publisher_group:123;publisher:456;s:123')
          RUBY
        end
      end

      context 'semicolons inside string literal' do
        it 'adds offense and autocorrects' do
          expect_offense(<<~RUBY)
            "00000000000000000;0000000000000000000'000000;00000'0000;0000;000"
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [66/40]
          RUBY

          expect_correction(<<~'RUBY')
            "00000000000000000;000000000000000000" \
            "0'000000;00000'0000;0000;000"
          RUBY
        end
      end
    end

    context 'HEREDOC' do
      let(:cop_config) { { 'Max' => 40, 'AllowURI' => false, 'AllowHeredoc' => false } }

      context 'when over limit with semicolon' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            foo = <<-SQL
              SELECT a b c d a b FROM c d a b c d ; COUNT(*) a b
                                                    ^^^^^^^^^^^^ Line is too long. [52/40]
            SQL
          RUBY

          expect_no_corrections
        end
      end

      context 'when HEREDOC start delimiter has a chained method with arguments that go over limit' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            str = <<~HEREDOC.do_something.with_args(foo: '', bar: '', baz: '')
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [66/40]
              text
            HEREDOC
          RUBY

          expect_no_corrections
        end

        it 'adds offense and does not autocorrect for `dstr`' do
          expect_offense(<<~'RUBY')
            str = <<~HEREDOC.do_something.with_args(foo: '', bar: '', baz: '')
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [66/40]
              #{text}
            HEREDOC
          RUBY

          expect_no_corrections
        end

        it 'adds offense and does not autocorrect for `xstr`' do
          expect_offense(<<~RUBY)
            str = <<~`HEREDOC`.do_something.with_args(foo: '', bar: '', baz: '')
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [68/40]
              text
            HEREDOC
          RUBY

          expect_no_corrections
        end
      end
    end

    context 'comments' do
      context 'when over limit with semicolon' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            # a b c d a b c d a b c d ; a b c d a b c d a b c d a
                                                    ^^^^^^^^^^^^^ Line is too long. [53/40]
          RUBY

          expect_no_corrections
        end
      end
    end

    context 'multiple assignment' do
      context 'when over limit at right hand side' do
        it 'registers and corrects an offense' do
          expect_offense(<<~RUBY)
            a = fooooooooooooooooooooooooooooooooooooo, b
                                                    ^^^^^ Line is too long. [45/40]
          RUBY

          expect_correction(<<~RUBY)
            a =#{trailing_whitespace}
            fooooooooooooooooooooooooooooooooooooo,#{trailing_whitespace}
            b
          RUBY
        end
      end
    end
  end
end
