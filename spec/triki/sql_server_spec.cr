require "../spec_helper"

Spectator.describe Triki::SqlServer do
  describe "#parse_insert_statement" do
    it "should return a hash of table_name, column_names for SQL Server input statements" do
      hash = subject.parse_insert_statement("INSERT [dbo].[TASKS] ([TaskID], [TaskName]) VALUES (61, N\"Report Thing\")")
      expect(hash).to eq({"table_name" => "TASKS", "column_names" => ["TaskID", "TaskName"]})
    end

    it "should return nil for SQL Server non-insert statements" do
      expect(subject.parse_insert_statement("CREATE TABLE [dbo].[WORKFLOW](")).to be_nil
    end

    it "should return nil for non-SQL Server insert statements (MySQL)" do
      expect(subject.parse_insert_statement(%{INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ("bob@honk.com","bob", "some\\"thin,ge())lse1", 25),("joe@joe.com","joe", "somethingelse2", 54);})).to be_nil
    end
  end

  describe "#rows_to_be_inserted" do
    it "should split a SQL Server string into fields" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (N'bob@bob.com',N'bob', N'somethingelse1',25, '2', 10,    'hi', CAST(0x00009E1A00000000 AS DATETIME))  ;  "
      fields = [["bob@bob.com", "bob", "somethingelse1", "25", "2", "10", "hi", "CAST(0x00009E1A00000000 AS DATETIME)"]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work ok with single quote escape" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (N'bob,@bob.c  , om', 'bo'', b', N'some\"thingel''se1', 25, '2', 10,    'hi', 5)  ; "
      fields = [["bob,@bob.c  , om", "bo'', b", "some\"thingel''se1", "25", "2", "10", "hi", "5"]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work ok with NULL values" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (NULL    , N'bob@bob.com','bob', NULL, 25, N'2', NULL,    'hi', NULL  ); "
      fields = [[nil, "bob@bob.com", "bob", nil, "25", "2", nil, "hi", nil]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work with empty strings" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (NULL    , N'', ''      , '', 25, '2','',    N'hi','') ;"
      fields = [[nil, "", "", "", "25", "2", "", "hi", ""]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end
  end

  describe "#make_valid_value_string" do
    it "should output 'NULL' when the value is nil" do
      expect(subject.make_valid_value_string(nil)).to eq("NULL")
    end

    it "should enclose the value in quotes if it's a string" do
      expect(subject.make_valid_value_string("something")).to eq("N'something'")
    end

    it "should not enclose the value in quotes if it is a method call" do
      expect(subject.make_valid_value_string("CAST(0x00009E1A00000000 AS DATETIME)")).to eq("CAST(0x00009E1A00000000 AS DATETIME)")
    end
  end
end
