#include <vector>
#include <iostream>
#include <algorithm>
#include <math.h>
#include <iomanip>
#include <pthread.h>
#include <cassert>
#include <time.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <fstream>
#include <atomic>
#include <sys/time.h>
#include <immintrin.h>
#include "busybarrier.h"

class PairHMM
{
    int num_states = 3;
    int num_emissions_i, num_emissions_j;
    double Qi, Qd, Qg;
    //double log_epsilon, log_delta;
    std::vector<std::vector<double>> emission_prob;
    std::vector<std::vector<double>> transition_prob;
    std::vector<double> init_prob;
    std::vector<double> confidence_scores;

public:
    PairHMM(std::istream &is);
    void forward_alg(const std::vector<int> &seq_i,
                     const std::vector<int> &seq_j,
                     const std::vector<double> &qbases,
                     bool printMatrices);

    void forward_alg_memo(const std::vector<int> &seq_i,
                                const std::vector<int> &seq_j,
                                const std::vector<double> &qbases,
                                bool printMatrices);

    void forward_alg_single_pass(const std::vector<int> &seq_i,
                                       const std::vector<int> &seq_j,
                                       const std::vector<double> &qbases,
                                       bool printMatrices);

    void forward_alg_scraping(const std::vector<int> &seq_i,
                                    const std::vector<int> &seq_j,
                                    const std::vector<double> &qbases,
                                    int width,
                                    bool printMatrices);

    void forward_alg_wrapping(const std::vector<int> &seq_i,
                                    const std::vector<int> &seq_j,
                                    const std::vector<double> &qbases,
                                    int width,
                                    bool printMatrices);

    void forward_alg_free(const std::vector<int> &seq_i,
                                const std::vector<int> &seq_j,
                                const std::vector<double> &qbases,
                                bool printMatrices);
};

struct hmm_cell
{
    double i_val;
    double j_val;
    double m_val;

    hmm_cell() : i_val(0.0), j_val(0.0), m_val(0.0) {}
};

struct hmm_arg_type0
{
    std::vector<std::vector<hmm_cell>> &memo;
    std::atomic<bool>** status;
    const std::vector<int> &seq_i;
    const std::vector<int> &seq_j;
    const std::vector<double> &qbases;
    pthread_barrier_t *brrr;
    const double &Qi, &Qd, &Qg;
    int i, j;
    const int &num_emissions_i, &num_emissions_j;
};

struct hmm_arg_type1
{
    std::vector<std::vector<hmm_cell>> &memo;
    const std::vector<int> &seq_i;
    const std::vector<int> &seq_j;
    const std::vector<double> &qbases;
    pthread_barrier_t *brrr;
    const double &Qi, &Qd, &Qg;
    int i, j;
    const int &num_emissions_i, &num_emissions_j;
};

struct hmm_arg_type2
{
    const std::vector<int> &seq_i;
    const std::vector<int> &seq_j;
    const std::vector<double> &qbases;
    pthread_barrier_t *brrr;
    const double &Qi, &Qd, &Qg;
    int i, j;
    hmm_cell *north, *west, *northwest;
    hmm_cell *output;
    hmm_cell *prev1, *prev2;
    const int &num_emissions_i, &num_emissions_j;
};

struct hmm_arg_type3
{
    const std::vector<int> &seq_i;
    const std::vector<int> &seq_j;
    const std::vector<double> &qbases;
    pthread_barrier_t *brrr;
    const double &Qi, &Qd, &Qg;
    int i, j, width, num_scrapes;
    std::vector<hmm_cell> &last_row;
    hmm_cell *north, *west, *northwest;
    hmm_cell *output;
    hmm_cell *prev1, *prev2;
    const int &num_emissions_i, &num_emissions_j;
};
