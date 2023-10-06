#include "CCDB/CcdbApi.h"
#include "Framework/Logger.h"
#include "QualityControl/MonitorObject.h"

#include "TCanvas.h"
#include "TDirectory.h"
#include "TFile.h"
#include "TH1F.h"
#include "TH2F.h"
#include "TObject.h"
#include "TObjArray.h"

#include <map>
#include <memory>
#include <string>

using namespace o2::quality_control::core;

/// Pull out the object of type T from a MonitorObject collection, i.e. an acutal histogram contained in a MonitorObject
template <typename T>
T* GetObjectFromMOs(TObjArray* moCollection, const char* name)
{   
    MonitorObject* mo = dynamic_cast<MonitorObject*>(moCollection->FindObject(name));
    T* obj = dynamic_cast<T*>(mo->getObject());
    return obj;
}

int ExtractLocalPlots(std::string qcfile)
{
    std::unique_ptr<TFile> qcFullrunFile(TFile::Open(qcfile.c_str()));
    TObjArray* moCollection = qcFullrunFile->Get<TObjArray>("FV0/Digits");
    MonitorObject* mo;
    TObject* qcPlot;

    std::unique_ptr<TFile> fOutputFile(TFile::Open("aqc_fv0.root", "RECREATE"));
    std::unique_ptr<TDirectory> dirFV0(fOutputFile->mkdir("FV0"));
    std::unique_ptr<TDirectory> dirDigits(dirFV0->mkdir("Digits"));
    std::unique_ptr<TDirectory> dirDigitsPrepared(dirFV0->mkdir("DigitsPrepared"));
    std::unique_ptr<TDirectory> dirDigitsChAmp(dirFV0->mkdir("DigitsPreparedChAmp"));

    for (int i = 0; i < moCollection->GetSize(); i++) {
        mo = dynamic_cast<MonitorObject*>(moCollection->At(i));
        qcPlot = mo->getObject();
        dirDigits->WriteObject(qcPlot, qcPlot->GetName());
    }

    TH1F* hSumAmpAXRange = GetObjectFromMOs<TH1F>(moCollection, "SumAmpA");
    hSumAmpAXRange->GetXaxis()->SetRangeUser(0, 5000);
    dirDigitsPrepared->WriteObject(hSumAmpAXRange, TString::Format("%sXRange", hSumAmpAXRange->GetName()));

    dirDigitsChAmp->cd();

    TH2F* hAmpPerChannel = GetObjectFromMOs<TH2F>(moCollection, "AmpPerChannel");
    for (int bin = 1; bin <= hAmpPerChannel->GetNbinsX(); bin++) {
        // This will also write the histogram to gDirectory
        TH1* hChAmp = hAmpPerChannel->ProjectionY(TString::Format("AmpCh%i", bin), bin, bin);
    }

    fOutputFile->Write();
    // fOutputFile->Close();
    return 0;
}

int ExtractQCDBPlots()
{
    LOG(error) << "Not implemented";
    return 1;
}

int ExtractAQCPlots(bool local = true, std::string qcfile = "QC_fullrun.root")
{
    if (local) {
        return ExtractLocalPlots(qcfile);
    } else {
        return ExtractQCDBPlots();
    }
}