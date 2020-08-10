#include "pair_hmm.h"

using namespace std;

extern void debug_init(int i, int j);
extern void debug_log(int i, int j, hmm_cell data);
extern void debug_print();

void *update_cell_single(void *);

void PairHMM::forward_alg_single_pass(const std::vector<int> &seq_i,
                                            const std::vector<int> &seq_j,
                                            const std::vector<double> &qbases,
                                            bool printMatrices)
{
    vector<vector<hmm_cell>> memo(3, vector<hmm_cell>(num_emissions_i + 1, hmm_cell())); // 3 dimensions: n, n-1, n-2
    pthread_t *threads = new pthread_t[num_emissions_i];
    hmm_arg_type2 **args = new hmm_arg_type2 *[num_emissions_i];
    pthread_barrier_t brrr;
    pthread_barrier_init(&brrr, NULL, num_emissions_i);

    debug_init(num_emissions_i + 1, num_emissions_j + 1);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    memo[2][0].m_val = 1.0; // initial northwest input, everthing else is 0.0
    for (int i = 0; i < num_emissions_i; ++i)
    {
        // essentially all the local arguments to this function
        args[i] = new hmm_arg_type2{seq_i, seq_j, qbases, &brrr, Qi, Qd, Qg,
                                    i + 1,           // i
                                    1 - i,           // j
                                    &memo[1][i],     // north
                                    &memo[1][i + 1], // west
                                    &memo[2][i],     // northwest
                                    &memo[0][i + 1], // output(n)
                                    &memo[1][i + 1], // output(n - 1)
                                    &memo[2][i + 1], // output(n - 2)
                                    num_emissions_i,
                                    num_emissions_j};

        pthread_create(threads + i, NULL, update_cell_single, (void *)args[i]);
    }
    for (int i = 0; i < num_emissions_i; ++i)
    {
        pthread_join(threads[i], NULL);
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    double result = memo[0].back().m_val + memo[0].back().i_val + memo[0].back().j_val;

    cout << "PTHREADS-NO-MEMO-OUTPUT: " << result << endl;
    cout << "Took " << elapsed << " usec." << endl;

    for (int i = 0; i < num_emissions_i; ++i)
    {
        delete args[i];
    }
    delete[] args;
    delete[] threads;
}

void *update_cell_single(void *args_)
{
    hmm_arg_type2 *args = (hmm_arg_type2 *)args_;
    const std::vector<int> &seq_i = args->seq_i;
    const std::vector<int> &seq_j = args->seq_j;
    const std::vector<double> &qbases = args->qbases;
    const double &Qi = args->Qi;
    const double &Qd = args->Qd;
    const double &Qg = args->Qg;
    const int &num_emissions_i = args->num_emissions_i;
    const int &num_emissions_j = args->num_emissions_j;
    const hmm_cell *north = args->north;
    hmm_cell *northwest = args->northwest;
    const hmm_cell *west = args->west;
    hmm_cell *output = args->output;
    // hopefully achieves better cache locality/sharing
    int i = args->i;
    int j = args->j;
    int count = 0;
    while (count < 2 * num_emissions_j)
    {
        if (j > 0 && j < num_emissions_j + 1)
        {
            output->i_val = Qg * north->i_val + Qi * north->m_val;
            output->j_val = Qg * west->j_val + Qd * west->m_val;

            double prior = (seq_i[i] == seq_j[j]) ? 1 - qbases[j] : qbases[j];
            double i_result = (1 - Qg) * northwest->i_val;
            double j_result = (1 - Qg) * northwest->j_val;
            double m_result = (1 - (Qi + Qd)) * northwest->m_val;
            output->m_val = prior * (m_result + i_result + j_result);
        } // no computation if j is non-negative or OOB
        pthread_barrier_wait(args->brrr);
        debug_log(i, j, *output);
        // update memo
        *args->prev2 = *args->prev1;
        *args->prev1 = *output;
        if (i == 1)
            northwest->m_val = 0.0;
        // next round
        ++count;
        ++j;
        pthread_barrier_wait(args->brrr);
    }
}
