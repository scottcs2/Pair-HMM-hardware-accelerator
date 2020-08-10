#include "pair_hmm.h"
#include <fstream>

using namespace std;

PairHMM::PairHMM(istream &is)
{
    is >> num_emissions_i >> num_emissions_j >> Qi >> Qd >> Qg;
    cout << "num i: " << num_emissions_i << endl;
    cout << "num j: " << num_emissions_j << endl;
    cout << "qi: " << Qi << endl;
    cout << "qd: " << Qd << endl;
    cout << "qg: " << Qg << endl;
}

void PairHMM::forward_alg(const std::vector<int> &seq_i,
                          const std::vector<int> &seq_j,
                          const std::vector<double> &qbases,
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
    ofstream outputFile("baseline_output.out", ios::out | ios::trunc);
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
}

/*
void PairHMM::viterbi_alg_log(const std::vector<int> &seq_i,
                          const std::vector<int> &seq_j) {
    vector<vector<double> > memo_m, memo_i, memo_j;
    vector<vector<char> > pmemo_m, pmemo_i, pmemo_j;  // p for pointer

    // initialize memos to all 0's (IxJ)
    memo_m = memo_i = memo_j = vector<vector<double> >(num_emissions_i, vector<double>(num_emissions_j, 0.0));
    pmemo_m = pmemo_i = pmemo_j = vector<vector<char> >(num_emissions_i, vector<char>(num_emissions_j, 0));

    // initial state
    memo_m[0][0] = 1.0;
    pmemo_m[0][0] = 'm';

    //Recrrence/DP
    for (int i = 0; i < num_emissions_i; ++i) {
        for (int j = 0; j < num_emissions_j; ++j) {
            if (j != 0) {
                // compute j matrix
                double m_result = log_delta + memo_m[i][j - 1];
                double j_result = log_epsilon + memo_j[i][j - 1];
                if (m_result > j_result) {
                    memo_j[i][j] = m_result + emission_prob[4][seq_j[j]];
                    pmemo_j[i][j] = 'm';
                } else {
                    memo_j[i][j] = j_result + emission_prob[4][seq_j[j]];
                    pmemo_j[i][j] = 'j';
                }
            }

            if (i != 0) {
                // compute i matrix
                double m_result = log_delta + memo_m[i - 1][j];
                double i_result = log_epsilon + memo_i[i - 1][j];
                if (m_result > i_result) {
                    memo_i[i][j] = m_result + emission_prob[seq_i[i]][4];
                    pmemo_i[i][j] = 'm';
                } else {
                    memo_i[i][j] = i_result + emission_prob[seq_i[i]][4];
                    pmemo_i[i][j] = 'i';
                }
            }

            if (i != 0 && j != 0) {
                // compute m matrix
                double m_result = log(1 - 2 * delta) + memo_m[i - 1][j - 1];
                double i_result = log(1 - epsilon) + memo_i[i - 1][j - 1];
                double j_result = log(1 - epsilon) + memo_j[i - 1][j - 1];

                double running_max = m_result;
                memo_m[i][j] = m_result;
                pmemo_m[i][j] = 'm';

                if (i_result > running_max) {
                    memo_m[i][j] = i_result;
                    pmemo_m[i][j] = 'i';
                    running_max = i_result;
                }

                if (j_result > running_max) {
                    memo_m[i][j] = j_result;
                    pmemo_m[i][j] = 'j';
                }

                memo_m[i][j] *= emission_prob[seq_i[i]][seq_j[j]];
            }
        }
    }

    double max_value = memo_m.back().back();
    char best_path = 'm';

    if (memo_i.back().back() > max_value) {
        max_value = memo_i.back().back();
        best_path = 'i';
    }

    if (memo_j.back().back() > max_value) {
        max_value = memo_j.back().back();
        best_path = 'j';
    }

    int x = num_emissions_i - 1;
    int y = num_emissions_j - 1;

    vector<char> state_sequence;

    // cout << x << " " << y << " " << best_path << endl;
    state_sequence.push_back(best_path);

    while (true) {
        switch (best_path) {
            case 'm':
                x--;
                y--;
                best_path = pmemo_m[x][y];
                break;
            case 'i':
                x--;
                best_path = pmemo_i[x][y];
                break;
            case 'j':
                y--;
                best_path = pmemo_j[x][y];
                break;
        }
        // cout << x << " " << y << " " << best_path << endl;
        state_sequence.push_back(best_path);

        if (x == 0 && y == 0)
            break;
    }

    reverse(state_sequence.begin(), state_sequence.end());

    cout << "Viterbi Summary for pair HMM" << endl;
    cout << "Most probable path:" << endl;
    for (int i = 0; i < state_sequence.size(); i++)
        cout << state_sequence[i] << " ";

    cout << endl;

    cout << "Probability of this path:" << endl;
    cout << max_value << endl;
}*/
