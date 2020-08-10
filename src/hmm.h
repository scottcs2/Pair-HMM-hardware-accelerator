#include <vector>
#include <iostream>
#include <fstream>
#include <limits>
#include <string>
#include <algorithm>

struct Sequence{
    bool capped;
    int S; // unique values
    std::vector<int> seq;
    void increment(); // change to next permutation
    void reset();
    bool cap();
    void print();
    Sequence(int _S);
    Sequence(int _S, const std::vector<int> v);
    Sequence();
};

class HMM {
    int num_states;
    int num_emissions;
    std::vector<std::vector<double> > emission_prob;
    std::vector<std::vector<double> > transition_prob;
    std::vector<double> init_prob;

public:
    HMM(std::istream &is);
    void brute_force(const std::vector<int> &emission_sequence);
    void forward_alg(const std::vector<int> &emission_sequence);
    void viterbi_alg(const std::vector<int> &emission_sequence);

};
