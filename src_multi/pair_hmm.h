#ifndef __PAIR_HMM__
#define __PAIR_HMM__

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
#include <sys/time.h>
#include <immintrin.h>
#include <atomic>

struct haplo_data
{
    int refLen;
    int haploLen;
    double Qi;
    double Qd;
    double Qg;
    std::vector<int> exp;
    std::vector<double> qbases;
};

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
    PairHMM();

    void read_data(haplo_data *hd, bool verbose);

    int forward_alg(const std::vector<int> &seq_i,
                    const std::vector<int> &seq_j,
                    const std::vector<double> &qbases,
                    std::ofstream &outputFile,
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

class PairHMM_Multi
{
    std::vector<haplo_data> batches;
    std::vector<int> reference_read;
    bool verbose;

    static void *forward_alg_multiT(void *);
    static void *forward_alg_multiT2(void *);
    static void * forward_alg_multiT3(void *args_);

public:
    PairHMM_Multi(std::istream &is);

    bool add_batch(std::istream &is);

    void enable_verbose();
    size_t max_batch_size();

    int forward_alg();
    int forward_alg_no_memo();
    int forward_alg_multi();
    int forward_alg_multi_no_memo();
    int forward_alg_multi_group_no_memo(int);
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
    std::atomic<bool> **status;
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

struct hmm_arg_type4
{
    const std::vector<int> &seq_i;
    haplo_data *hd;
    double *result;
};

struct hmm_arg_type5
{
    const std::vector<int> &seq_i;
    haplo_data *hd_begin, *hd_end;
    double *result_begin, *result_end;
};

#endif