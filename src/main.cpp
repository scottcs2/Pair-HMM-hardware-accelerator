#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <string>
#include "hmm.h"
#include "pair_hmm.h"

using namespace std;

int main(int argc, char **argv) {
    // HMM hmm(cin);

    // vector<int> test = {0, 1};

    // hmm.brute_force(test);

    // hmm.forward_alg(test);

    // hmm.viterbi_alg(test);

    bool verbose = argc == 2;

    ifstream testData("test.data", ios::in);
    string tmp;
    getline(testData, tmp);
    cout << tmp << endl;

    PairHMM phmm(testData);

    string seq1, seq2;
    string qbases_str; // ascii string

    //cout << "enter seq1: " << endl;
    testData >> seq1;
    //cout << "enter seq2: " << endl;
    testData >> seq2;
    //cout << "enter qbases: " << endl;
    testData >> qbases_str;

    vector<int> v1, v2;
    vector<double> qbases;

    cout << "REFERENCE: " << endl;
    cout << seq1 << endl;
    cout << "EXPERIMENT: " << endl;
    cout << seq2 << endl;
    cout << "QBASES: " << endl;
    cout << qbases_str << endl;

    // (T,C,G,A,-) = (0,1,2,3,4)
    qbases.push_back(0);
    for(int i = 0; i < qbases_str.length(); i++) {
        double converted = pow(10, -0.1 * qbases_str[i]);
        if(verbose) {
            cout << "qbase: " << qbases_str[i] << " converted to: " << converted << endl;
        }
        qbases.push_back(converted);
        // qbases.push_back(pow(10, -0.1 * qbases_str[i]));
    }

    v1.push_back(4);
    for (int i = 0; i < seq1.length(); i++) {
        switch (seq1[i]) {
            case 'T':
                v1.push_back(0);
                break;
            case 'C':
                v1.push_back(1);
                break;
            case 'G':
                v1.push_back(2);
                break;
            case 'A':
                v1.push_back(3);
                break;
            case '-':
                v1.push_back(4);
                break;
        }
    }

    v2.push_back(4);
    for (int i = 0; i < seq2.length(); i++) {
        switch (seq2[i]) {
            case 'T':
                v2.push_back(0);
                break;
            case 'C':
                v2.push_back(1);
                break;
            case 'G':
                v2.push_back(2);
                break;
            case 'A':
                v2.push_back(3);
                break;
            case '-':
                v2.push_back(4);
                break;
        }
    }
    cout << endl;
    //phmm.viterbi_alg(v1, v2);

// #define DEBUG
    phmm.forward_alg(v1, v2, qbases, verbose);
    // phmm.forward_alg_memo(v1, v2, qbases, verbose);
    // phmm.forward_alg_free(v1, v2, qbases, verbose);
    phmm.forward_alg_single_pass(v1, v2, qbases, verbose);
    phmm.forward_alg_scraping(v1, v2, qbases, 5, verbose);
    phmm.forward_alg_scraping(v1, v2, qbases, 20, verbose);
    phmm.forward_alg_scraping(v1, v2, qbases, v1.size() / 4, verbose);
    return 0;
}
