#include "pair_hmm.h"
#include <fstream>

using namespace std;

PairHMM::PairHMM() { }

void PairHMM::read_data(haplo_data* hd, bool verbose)
{
    num_emissions_i = hd->refLen;
    num_emissions_j = hd->haploLen;
    Qi = hd->Qi;
    Qd = hd->Qd;
    Qg = hd->Qg;
    // num_emissions_i = refLen;
    // is >> Qi >> Qd >> Qg >> num_emissions_j;
    //is >> num_emissions_i >> num_emissions_j >> Qi >> Qd >> Qg;
    if(verbose) {
        cout << "num i: " << num_emissions_i << endl;
        cout << "num j: " << num_emissions_j << endl;
        cout << "qi: " << Qi << endl;
        cout << "qd: " << Qd << endl;
        cout << "qg: " << Qg << endl;
    }
}

int PairHMM::forward_alg(const std::vector<int> &seq_i,
                          const std::vector<int> &seq_j,
                          const std::vector<double> &qbases,
                          ofstream &outputFile,
                          bool printMatrices)
{
    vector<vector<double> > memo_m, memo_i, memo_j;
    vector<vector<char> > pmemo_m, pmemo_i, pmemo_j; // p for pointer

    // initialize memos to all 0's (IxJ)
    memo_m = memo_i = memo_j = vector<vector<double> >(num_emissions_i + 1, vector<double>(num_emissions_j + 1, 0.0));
    pmemo_m = pmemo_i = pmemo_j = vector<vector<char> >(num_emissions_i + 1, vector<char>(num_emissions_j + 1, 0));

    // initial state
    memo_m[0][0] = 1;
    pmemo_m[0][0] = 'b';

    double prior;
    
    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    for (int i = 1; i <= num_emissions_i; ++i)
    {
        for (int j = 1; j <= num_emissions_j; ++j)
        {
            if (j != 0)
            {
                // compute j (D) matrix
                double m_result = Qd * memo_m[i][j - 1];
                double j_result = Qg * memo_j[i][j - 1];

                memo_j[i][j] = m_result + j_result;
            }

            if (i != 0)
            {
                // compute i matrix
                double m_result = Qi * memo_m[i - 1][j];
                double i_result = Qg * memo_i[i - 1][j];

                memo_i[i][j] = m_result + i_result;
            }

            if (i != 0 && j != 0)
            {
                // compute m matrix
                prior = (seq_i[i] == seq_j[j]) ? 1 - qbases[j] : qbases[j];
                double m_result = (1 - (Qi + Qd)) * memo_m[i - 1][j - 1];
                double i_result = (1 - Qg) * memo_i[i - 1][j - 1];
                double j_result = (1 - Qg) * memo_j[i - 1][j - 1];

                memo_m[i][j] = prior * (m_result + i_result + j_result);
            }
        }
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;
    double result = memo_m[num_emissions_i][num_emissions_j] +
                    memo_i[num_emissions_i][num_emissions_j] +
                    memo_j[num_emissions_i][num_emissions_j];
    cout << "SINGLE-OUTPUT: " << setprecision(20) << result << endl;
    //ofstream outputFile("multi_baseline_output.out", ios::out | ios::trunc);
    outputFile << result << endl;
    cout << "Took " << elapsed << " usec." << endl;

    if (printMatrices)
    {
        cout << "FM MATRIX: " << endl;
        for (int i = 0; i <= num_emissions_i; ++i)
        {
            for (int j = 0; j <= num_emissions_j; ++j)
            {
                cout << setprecision(5) << setw(15) << memo_m[i][j];
            }
            cout << endl;
        }

        cout << endl;

        cout << "FI MATRIX: " << endl;
        for (int i = 0; i <= num_emissions_i; ++i)
        {
            for (int j = 0; j <= num_emissions_j; ++j)
            {
                cout << setprecision(5) << setw(15) << memo_i[i][j];
            }
            cout << endl;
        }

        cout << endl;

        cout << "FD MATRIX: " << endl;
        for (int i = 0; i <= num_emissions_i; ++i)
        {
            for (int j = 0; j <= num_emissions_j; ++j)
            {
                cout << setprecision(5) << setw(15) << memo_j[i][j];
            }
            cout << endl;
        }
    }

    return elapsed; 
}