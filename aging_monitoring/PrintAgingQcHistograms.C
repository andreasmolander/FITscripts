#include <FairLogger.h>
#include <QualityControl/MonitorObject.h>

#include <TFile.h>
#include <TH1.h>
#include <TH2.h>
#include <TObjArray.h>

#include <fstream>
#include <memory>

/// \file PrintAgingQcHistograms.C
/// \brief This script prints the bin contents of the aging QC histograms to a CSV file.

using namespace o2::quality_control::core;

/// Pull out the object of type T from a MonitorObject collection,
/// i.e. an acutal histogram contained in a MonitorObject.
template <typename T>
T* GetObjectFromMOs(TObjArray* moCollection, const char* name)
{
  MonitorObject* mo = dynamic_cast<MonitorObject*>(moCollection->FindObject(name));
  T* obj = dynamic_cast<T*>(mo->getObject());
  return obj;
}

void WriteHistogramsToCSV(const char* outputFileName, TObjArray* histograms) {
  // Open the output CSV file for writing
  std::ofstream fCsv(outputFileName);

  // Check if the file opened successfully
  if (!fCsv.is_open()) {
    LOG(error) << "Unable to open CSV file for writing.";
    return;
  }

  // Get the number of bins from the first histogram (assuming all histograms have the same binning)
  TH1* hFirst = dynamic_cast<TH1*>(histograms->At(0));
  int nBins = hFirst ? hFirst->GetNbinsX() : 0;

  // Write the header line with column names
  fCsv << "ADC ch";
  for (int i = 0; i < histograms->GetSize(); ++i) {
    TH1* hist = dynamic_cast<TH1*>(histograms->At(i));
    if (hist) {
      fCsv << "," << hist->GetName();
    }
  }
  fCsv << "\n";

  // Loop through the bins and write bin values and contents for each histogram
  for (int bin = 1; bin <= nBins; bin++) {
    // csvFile << firstHist->GetBinCenter(bin); // Write bin value in the first column
    fCsv << hFirst->GetBinLowEdge(bin);

    for (int i = 0; i < histograms->GetSize(); i++) {
      TH1* hist = dynamic_cast<TH1*>(histograms->At(i));
      if (hist) {
        fCsv << "," << hist->GetBinContent(bin);
      }
    }
    fCsv << "\n";
  }

  fCsv.close();

  LOG(info) << "CSV file '" << outputFileName << "' has been created.";
}

void PrintAgingQcHistograms(const char* inputFileName = "ft0_aging_monitoring_qc.root",
              const char* outputFileName = "ft0_aging_monitoring_amplitudes.csv")
{
  // Open the input file and get the collection of MonitorObjects
  std::unique_ptr<TFile> fInput(TFile::Open(inputFileName, "READ"));
  TObjArray* moCollection = fInput->Get<TObjArray>("FT0/AgingMonitoring");
  MonitorObject* mo;

  TObjArray* histograms = new TObjArray();

  // Amplitude per detector channel and ADC
  TH2* hAmpPerChannel;
  for(int iADC = 0; iADC <= 1; iADC++) {
    hAmpPerChannel = GetObjectFromMOs<TH2>(moCollection, Form("AmpPerChannelADC%i", iADC));
    for (int iChId = 0; iChId <= 207; iChId++) {
      histograms->Add(hAmpPerChannel->ProjectionY(Form("AmpCh%iADC%i", iChId, iADC), iChId+1, iChId+1));
    }
  }
  
  // Reference peaks
  for (int iChId = 208; iChId <= 211; iChId++) {
    for (int iPeak = 1; iPeak <= 2; iPeak++) {
      for (int iADC = 0; iADC <= 1; iADC++) {
        histograms->Add(GetObjectFromMOs<TH1>(moCollection, Form("AmpCh%iPeak%iADC%i", iChId, iPeak, iADC)));
      }
    }
  }

  // Write the histograms' bin contents to the CSV file
  WriteHistogramsToCSV(outputFileName, histograms);

  // Clean up
  delete histograms;
  fInput->Close();
}