unit Test.radIDETerminal.Smoke;

interface

uses
  DUnitX.TestFramework;

type

  [TestFixture]
  TDUnitXToolingValidation = class
  public

  ///<summary> Smoke test just to ensure the basic tooling is operational </summary>
  [Test] procedure ShouldReportSuccess;

  end;

implementation


procedure TDUnitXToolingValidation.ShouldReportSuccess;
begin
  Assert.IsTrue(True, 'Smoketest - should be true');
end;

initialization
  TDUnitX.RegisterTestFixture(TDUnitXToolingValidation);

end.
