#include "pair_hmm.h"

using namespace std;

extern void debug_init(int i, int j);
extern void debug_log(int i, int j, hmm_cell data);
extern void debug_print();

void *update_cell_free(void *);

void PairHMM::forward_alg_free(const std::vector<int> &seq_i,
                                     const std::vector<int> &seq_j,
                                     const std::vector<double> &qbases,
                                     bool printMatrices)
{
    vector<vector<hmm_cell>> memo(num_emissions_i + 1, vector<hmm_cell>(num_emissions_j + 1));;
    atomic_bool** status = new atomic_bool*[num_emissions_i + 1];

    debug_init(num_emissions_i + 1, num_emissions_j + 1);

    pthread_t *threads = new pthread_t[num_emissions_i];
    hmm_arg_type0 **args = new hmm_arg_type0 *[num_emissions_i];
    pthread_barrier_t brrr;
    pthread_barrier_init(&brrr, NULL, num_emissions_i);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    memo[0][0].m_val = 1; // initial state
    for(int i = 0; i < num_emissions_i + 1; ++i){
        status[i] = new atomic_bool[num_emissions_j + 1];
        for(int j = 0; j < num_emissions_j + 1; ++j)
            status[i][j].store(i == 0);
        status[i][0].store(true);
    }
    for (int i = 0; i < num_emissions_i; ++i)
    {
        // essentially all the local arguments to this function
        args[i] = new hmm_arg_type0{memo, status, seq_i, seq_j, qbases, &brrr, Qi, Qd, Qg,
                                   i + 1, 1 - i, num_emissions_i, num_emissions_j};
        pthread_create(threads + i, NULL, update_cell_free, (void *)args[i]);
    }
    for (int i = 0; i < num_emissions_i; ++i)
    {
        pthread_join(threads[i], NULL);
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    double result = memo[num_emissions_i][num_emissions_j].m_val +
                    memo[num_emissions_i][num_emissions_j].i_val +
                    memo[num_emissions_i][num_emissions_j].j_val;
    cout << "PTHREADS-FREE-OUTPUT: " << result << endl;
    cout << "Took " << elapsed << " usec." << endl;
    ofstream outputFile("mt_baseline_output.out", ios::out | ios::trunc);
    outputFile << result << endl;

    for (int i = 0; i < num_emissions_i; ++i)
    {
        delete args[i];
    }
    delete[] args;
    delete[] threads;
    
    debug_print();
}

// ouch
void *update_cell_free(void *args_)
{
    static pthread_mutex_t cout_lock;
    pthread_mutex_init(&cout_lock, NULL);
    hmm_arg_type0 *args = (hmm_arg_type0 *)args_;
    vector<vector<hmm_cell>> &memo = args->memo;
    atomic_bool** status = args->status;
    const std::vector<int> &seq_i = args->seq_i;
    const std::vector<int> &seq_j = args->seq_j;
    const std::vector<double> &qbases = args->qbases;
    const double &Qi = args->Qi;
    const double &Qd = args->Qd;
    const double &Qg = args->Qg;
    const int &num_emissions_i = args->num_emissions_i;
    const int &num_emissions_j = args->num_emissions_j;
    // hopefully achieves better cache locality/sharing
    int i = args->i;
    int j = args->j;
    int count = 0;
    while (count < 2 * num_emissions_j)
    {
        if (j > 0 && j < num_emissions_j + 1)
        {
            while(!status[i - 1][j].load());
            memo[i][j].i_val = Qg * memo[i - 1][j].i_val + Qi * memo[i - 1][j].m_val;
            while(!status[i - 1][j].load());
            memo[i][j].j_val = Qg * memo[i][j - 1].j_val + Qd * memo[i][j - 1].m_val;

            while(!status[i - 1][j - 1].load());
            double prior = (seq_i[i] == seq_j[j]) ? 1 - qbases[j] : qbases[j];
            double i_result = (1 - Qg) * memo[i - 1][j - 1].i_val;
            double j_result = (1 - Qg) * memo[i - 1][j - 1].j_val;
            double m_result = (1 - (Qi + Qd)) * memo[i - 1][j - 1].m_val;
            memo[i][j].m_val = prior * (m_result + i_result + j_result);
            status[i][j].store(true);
            debug_log(i, j, memo[i][j]);
        } // do nothing if j is non-negative or OOB
        ++j;
        ++count;
        pthread_barrier_wait(args->brrr);
    }
}