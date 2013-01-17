describe Currency do
  it "should convert from JOD to USD" do
    Currency['JOD'].from('USD', 10).to_f.should == 7.0
    Currency['USD'].from('JOD', 7.0).to_f.should == 10.0
  end

  it "should convert from USD to JOD" do
    Currency['USD'].from('JOD', 10).to_f.should == 14.29
    Currency['JOD'].to('USD', 10).to_f.should == 14.29
  end

  it "should not do anything with a USD amount on conversion" do
    Currency["USD"].from('USD', 10).to_f.should == 10.0
  end
end