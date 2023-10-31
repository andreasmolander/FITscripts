#include "Framework/Logger.h"
#include "QualityControl/MonitorObject.h"

#include "TCanvas.h"
#include "TDirectory.h"
#include "TFile.h"
#include "TH1.h"
#include "TH1F.h"
#include "TH2F.h"
#include "TLegend.h"
#include "TObject.h"
#include "TObjArray.h"
#include "TSystem.h"

#include <algorithm>
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

    // BC per trigger shown as 1D histograms
    dirDigitsPrepared->cd();
    TH2F* hBCvsTriggers = GetObjectFromMOs<TH2F>(moCollection, "BCvsTriggers");
    TCanvas* cBCperTrigger = new TCanvas("cBCperTrigger", "cBCperTrigger");
    TCanvas* cBCperTriggerZoom = new TCanvas("cBCperTriggerZoom", "cBCperTriggerZoom");
    TLegend* legBCperTrigger = new TLegend(0.1, 0.7, 0.48, 0.9);

    std::vector<TH1*> bcHistos;
    std::vector<TH1*> bcHistosZoom;

    for (int yBin = 1; yBin <= hBCvsTriggers->GetNbinsY(); yBin++) {
        const char* triggerName = hBCvsTriggers->GetYaxis()->GetBinLabel(yBin);
        // This will also write the histogram to gDirectory
        TH1* hBc = hBCvsTriggers->ProjectionX(TString::Format("bc_%s", triggerName), yBin, yBin);
        bcHistos.push_back(hBc);

        // This will also write the histogram to gDirectory
        TH1* hBcZoom = dynamic_cast<TH1*>(hBc->Clone(Form("%sZoom", hBc->GetName())));
        hBcZoom->GetXaxis()->SetRangeUser(1000, 1100);
        bcHistosZoom.push_back(hBcZoom);
    }

    // sort bc histos based on number of entries
    std::sort(bcHistos.begin(), bcHistos.end(), [](const TH1* a, const TH1* b) {
        return a->GetEntries() > b->GetEntries();
    });
    std::sort(bcHistosZoom.begin(), bcHistosZoom.end(), [](const TH1* a, const TH1* b) {
        return a->GetEntries() > b->GetEntries();
    });

    for (int i = 0; i < bcHistos.size(); i++) {
        bcHistos.at(i)->SetLineColor(i + 1);
        bcHistos.at(i)->SetStats(kFALSE);
        bcHistosZoom.at(i)->SetLineColor(i + 1);
        bcHistosZoom.at(i)->SetStats(kFALSE);

        legBCperTrigger->AddEntry(bcHistos.at(i), bcHistos.at(i)->GetName(), "l");
        
        cBCperTrigger->cd();
        bcHistos.at(i)->Draw(i == 0 ? "" : "same");
        cBCperTriggerZoom->cd();
        bcHistosZoom.at(i)->Draw(i == 0 ? "" : "same");
    }
    cBCperTrigger->cd();
    legBCperTrigger->Draw();
    cBCperTrigger->Write();

    cBCperTriggerZoom->cd();
    legBCperTrigger->Draw();
    cBCperTriggerZoom->Write();

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

int PrintPlots()
{
    if (gSystem->AccessPathName("plots")) {
        gSystem->mkdir("plots");
    }

    std::unique_ptr<TFile> fOutputFile(TFile::Open("aqc_fv0.root", "READ"));

    std::unique_ptr<TCanvas> c(fOutputFile->Get<TCanvas>("FV0/DigitsPrepared/cBCperTrigger"));
    c->SetLogy();
    c->Draw();
    c->Print("plots/cBCperTrigger.png");
    
    c.reset(fOutputFile->Get<TCanvas>("FV0/DigitsPrepared/cBCperTriggerZoom"));
    c->SetLogy();
    c->Draw();
    c->Print("plots/cBCperTriggerZoom.png");

    fOutputFile->Close();
    return 0;
}

int ExtractAQCPlots(bool local = true, std::string qcfile = "QC_fullrun.root")
{
    if (local) {
        ExtractLocalPlots(qcfile);
    } else {
        ExtractQCDBPlots();
    }
    PrintPlots();

    return 0;
}