#include "hmm.h"

using namespace std;

HMM::HMM(istream &is) {
    // read in N and M
    is >> num_states >> num_emissions;

    for (int i = 0; i < num_states; ++i) {
        emission_prob.emplace_back();
        for (int j = 0; j < num_emissions; j++) {
            double d;
            is >> d;
            emission_prob[i].push_back(d);
        }
    }

    for (int i = 0; i < num_states; ++i) {
        transition_prob.emplace_back();
        for (int j = 0; j < num_states; j++) {
            double d;
            is >> d;
            transition_prob[i].push_back(d);
        }
    }

    for (int i = 0; i < num_states; ++i) {
        double d;
        is >> d;
        init_prob.push_back(d);
    }

    /*
    cout << num_states << " " << num_emissions << endl << endl;
    for (int i = 0; i < num_states; ++i) {
        for (int j = 0; j < num_emissions; ++j) {
            cout << emission_prob[i][j] << " ";
        }
        cout << endl;
    }

    cout << endl;
    for (int i = 0; i < num_states; ++i) {
        for (int j = 0; j < num_states; ++j) {
            cout << transition_prob[i][j] << " ";
        }
        cout << endl;
    }

    cout << endl;
    for (int i = 0; i < num_states; ++i) {
            cout << init_prob[i] << " ";
    }
    cout << endl;*/
}

void HMM::brute_force(const vector<int> &emission_sequence) {
    Sequence state_it(emission_sequence.size());

    double sum = 0.0;
    double max = 0;  //numeric_limits<double>::infinity();
    Sequence max_seq;
    while (!state_it.cap()) {
        // for each possible state sequence
        double obsv_prob = 1.0;  // P(x | R, theta)
        double trns_prob = init_prob[state_it.seq.front()];
        for (int i = 0; i < state_it.seq.size(); ++i) {
            int st = state_it.seq[i];
            int x = emission_sequence[i];
            obsv_prob *= emission_prob[st][x];
        }

        for (int i = 0; i < state_it.seq.size() - 1; ++i) {
            int curr = state_it.seq[i];
            int next = state_it.seq[i + 1];
            trns_prob *= transition_prob[curr][next];
        }

        double result = trns_prob * obsv_prob;
        if (result > max) {
            max = result;
            max_seq = state_it;
        }

        sum += result;
        state_it.increment();
    }

    cout << "--Brute force summary" << endl;
    cout << "Maximum: " << max << endl;
    cout << "Most probable state sequence: ";
    max_seq.print();
    cout << endl;
    cout << "Overall emission probability: " << sum << endl;
}

void HMM::forward_alg(const std::vector<int> &emission_sequence) {
    // memo[state][observation]
    vector<vector<double> > memo(num_states, vector<double>(emission_sequence.size(), 0.0));

    // initial conditions
    for (int i = 0; i < num_states; ++i) {
        memo[i][0] = init_prob[i] * emission_prob[i][emission_sequence[0]];
    }

    double sum = 0.0;
    for (int j = 1; j < emission_sequence.size(); ++j) {  // for each observation
        for (int i = 0; i < num_states; ++i) {            // for each state
            //α(n,i)=∑k[α(n−1,k)t(k,i)e(xn|i)]
            int e = emission_sequence[j];
            memo[i][j] = 0.0;
            for (int k = 0; k < num_states; ++k) {
                memo[i][j] += memo[k][j - 1] * transition_prob[k][i];
            }
            memo[i][j] *= emission_prob[i][e];
        }
    }

    for (int i = 0; i < num_states; ++i) {
        sum += memo[i].back();
    }

    cout << "--Forward HMM Summary" << endl;
    cout << "Overall emission probability: " << sum << endl;
}

void HMM::viterbi_alg(const std::vector<int> &emission_sequence) {
    // memo[state][observation]
    vector<vector<double> > memo(num_states, vector<double>(emission_sequence.size(), 0.0));
    vector<int> bpath(emission_sequence.size(), -1);
    // initial conditions
    double maximum = 0.0;
    for (int i = 0; i < num_states; ++i) {
        memo[i][0] = init_prob[i] * emission_prob[i][emission_sequence[0]];
        if (memo[i][0] > maximum) {
            bpath[0] = i;
            maximum = memo[i][0];
        }
    }

    for (int j = 1; j < emission_sequence.size(); ++j) {  // for each observation
        for (int i = 0; i < num_states; ++i) {            // for each state
            int e = emission_sequence[j];
            //  γ(n,i)=maxk[γ(n−1,k)t(k,i)e(xn|i)]
            memo[i][j] = 0.0;
            for (int k = 0; k < num_states; ++k) {
                double temp = memo[k][j - 1] * transition_prob[k][i];
                if (temp > memo[i][j]) {
                    memo[i][j] = temp;
                    bpath[j] = k;
                }
            }
            memo[i][j] *= emission_prob[i][e];
        }
    }
    //  P∗=maxyP{x,y|Θ}=maxkγ(L,k)

    maximum = 0.0;
    for (int i = 0; i < num_states; ++i) {
        maximum = max(maximum, memo[i].back());
    }

    cout << "--Viterbi HMM Summary" << endl;
    cout << "Maximum: " << maximum << endl;
    cout << "Most probable state sequence: ";
    for (int i = 0; i < bpath.size(); ++i) {
        cout << bpath[i] << " ";
    }
    cout << endl;
}

Sequence::Sequence(int _S) : capped(0), S(_S), seq(_S, 0) {}
Sequence::Sequence(int _S, const vector<int> v) : capped(0), S(_S), seq(v) {}
Sequence::Sequence() : capped(0) {}

void Sequence::reset() {
    for (int i = 0; i < seq.size(); ++i)
        seq[i] = 0;
    capped = false;
}

bool Sequence::cap() {
    return capped;
}

void Sequence::increment() {
    int i = 0;
    while (i < seq.size() && seq[i] == S - 1) {
        seq[i] = 0;
        ++i;
        if (i == seq.size())
            capped = true;
    }

    if (i < seq.size()) {
        ++seq[i];
    }
}

void Sequence::print() {
    for (int i = 0; i < seq.size(); ++i) {
        cout << seq[i];
        if (i != seq.size() - 1)
            cout << " ";
    }
}