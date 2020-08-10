#include "pair_hmm.h"

using namespace std;

extern void debug_init(int i, int j);
extern void debug_log(int i, int j, hmm_cell data);
extern void debug_print();

void *update_cell_scraping_head(void *);
void *update_cell_scraping_body(void *);
void *update_cell_scraping_tail(void *);

void PairHMM::forward_alg_scraping(const std::vector<int> &seq_i,
                                         const std::vector<int> &seq_j,
                                         const std::vector<double> &qbases,
                                         int width,
                                         bool printMatrices)
{
    if (width < 3)
    {
        cout << "ERROR: scraping requires width of 3 or more (input was " << width << ")" << endl;
        exit(1);
    }
    vector<vector<hmm_cell>> memo(3, vector<hmm_cell>(width + 1, hmm_cell())); // 3 dimensions: n, n-1, n-2
    pthread_t *threads = new pthread_t[width];
    hmm_arg_type3 **args = new hmm_arg_type3 *[width];
    pthread_barrier_t brrr;
    pthread_barrier_init(&brrr, NULL, width);

    debug_init(num_emissions_i + 1, num_emissions_j + 1);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    vector<hmm_cell> last_row(num_emissions_j + 1, hmm_cell());
    memo[2][0].m_val = 1.0; // initial northwest input, everthing else is 0.0
    last_row[0].m_val = 1.0;
    int num_scrapes = num_emissions_i / width + ((num_emissions_i % width == 0) ? 0 : 1);
    for (int i = 0; i < width; ++i)
    {
        // essentially all the local arguments to this function
        args[i] = new hmm_arg_type3{seq_i, seq_j, qbases, &brrr, Qi, Qd, Qg,
                                    i + 1, // i
                                    1 - i, // j
                                    width,
                                    num_scrapes,
                                    last_row,
                                    &memo[1][i],     // north
                                    &memo[1][i + 1], // west
                                    &memo[2][i],     // northwest
                                    &memo[0][i + 1], // output(n)
                                    &memo[1][i + 1], // output(n - 1)
                                    &memo[2][i + 1], // output(n - 2)
                                    num_emissions_i,
                                    num_emissions_j};
        if (i == 0)
            pthread_create(threads + i, NULL, update_cell_scraping_head, (void *)args[i]);
        else if (i == width - 1)
            pthread_create(threads + i, NULL, update_cell_scraping_tail, (void *)args[i]);
        else
            pthread_create(threads + i, NULL, update_cell_scraping_body, (void *)args[i]);
    }
    int final_index;
    if (num_emissions_i % width == 0)
    {
        final_index = width;
    }
    else
    {
        final_index = num_emissions_i % width;
    }
    for (int i = 0; i < width; ++i)
    {
        pthread_join(threads[i], NULL);
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    double result = memo[0][final_index].m_val +
                    memo[0][final_index].i_val +
                    memo[0][final_index].j_val;

    cout << "PTHREADS-SCRAPE(" << width << ")-OUTPUT: " << result << endl;
    cout << "performed " << num_scrapes << " passes" << endl;
    cout << "Took " << elapsed << " usec." << endl;
    for (int i = 0; i < width; ++i)
    {
        delete args[i];
    }
    delete[] threads;
    delete[] args;

    debug_print();
}

void *update_cell_scraping_head(void *args_)
{
    hmm_arg_type3 *args = (hmm_arg_type3 *)args_;
    const std::vector<int> &seq_i = args->seq_i;
    const std::vector<int> &seq_j = args->seq_j;
    const std::vector<double> &qbases = args->qbases;
    const double &Qi = args->Qi;
    const double &Qd = args->Qd;
    const double &Qg = args->Qg;
    const int &num_emissions_i = args->num_emissions_i;
    const int &num_emissions_j = args->num_emissions_j;
    hmm_cell *north = args->north;
    hmm_cell *northwest = args->northwest;
    hmm_cell *west = args->west;
    hmm_cell *output = args->output;
    // hopefully achieves better cache locality/sharing
    int i = args->i;
    int j = args->j;
    int &width = args->width;
    std::vector<hmm_cell> &last_row = args->last_row;
    int count = 0;
    int scrape_count = 0;
    while (scrape_count < args->num_scrapes)
    {
        *args->prev2 = hmm_cell();
        *args->prev1 = hmm_cell();
        *output = hmm_cell();
        // pass j dimension once
        while (count < 2 * num_emissions_j)
        {
            if (j > 0 && j < num_emissions_j + 1 && i < num_emissions_i + 1)
            {

                output->i_val = Qg * last_row[j].i_val + Qi * last_row[j].m_val;
                output->j_val = Qg * west->j_val + Qd * west->m_val;

                double prior = (seq_i[i] == seq_j[j]) ? 1 - qbases[j] : qbases[j];
                double i_result = (1 - Qg) * last_row[j - 1].i_val;
                double j_result = (1 - Qg) * last_row[j - 1].j_val;
                double m_result = (1 - (Qi + Qd)) * last_row[j - 1].m_val;
                output->m_val = prior * (m_result + i_result + j_result);
                debug_log(i, j, *output);
            } // no computation if j is non-negative or OOB or i OOB
            pthread_barrier_wait(args->brrr);
            // next round
            if (j == 1 && i == 1)
                last_row[0].m_val = northwest->m_val = 0.0;
            ++count;
            ++j;
            *args->prev2 = *args->prev1;
            *args->prev1 = *output;
            pthread_barrier_wait(args->brrr);
        }
        count = 0;
        i += width;
        j = args->j;
        ++scrape_count;
    }
}

void *update_cell_scraping_body(void *args_)
{
    static pthread_mutex_t cout_lock;
    pthread_mutex_init(&cout_lock, NULL);
    hmm_arg_type3 *args = (hmm_arg_type3 *)args_;
    const std::vector<int> &seq_i = args->seq_i;
    const std::vector<int> &seq_j = args->seq_j;
    const std::vector<double> &qbases = args->qbases;
    const double &Qi = args->Qi;
    const double &Qd = args->Qd;
    const double &Qg = args->Qg;
    const int &num_emissions_i = args->num_emissions_i;
    const int &num_emissions_j = args->num_emissions_j;
    hmm_cell *north = args->north;
    hmm_cell *northwest = args->northwest;
    hmm_cell *west = args->west;
    hmm_cell *output = args->output;
    // hopefully achieves better cache locality/sharing
    int i = args->i;
    int j = args->j;
    int &width = args->width;
    std::vector<hmm_cell> &last_row = args->last_row;
    int count = 0;
    int scrape_count = 0;
    while (scrape_count < args->num_scrapes)
    {
        *args->prev2 = hmm_cell();
        *args->prev1 = hmm_cell();
        *output = hmm_cell();
        // pass j dimension once
        while (count < 2 * num_emissions_j)
        {
            if (j > 0 && j < num_emissions_j + 1 && i < num_emissions_i + 1)
            {
                output->i_val = Qg * north->i_val + Qi * north->m_val;
                output->j_val = Qg * west->j_val + Qd * west->m_val;

                double prior = (seq_i[i] == seq_j[j]) ? 1 - qbases[j] : qbases[j];
                double i_result = (1 - Qg) * northwest->i_val;        // memo_i[i - 1][j - 1];
                double j_result = (1 - Qg) * northwest->j_val;        // memo_j[i - 1][j - 1];
                double m_result = (1 - (Qi + Qd)) * northwest->m_val; // memo_m[i - 1][j - 1];
                output->m_val = prior * (m_result + i_result + j_result);
                debug_log(i, j, *output);
            } // no computation if j is non-negative or OOB or i OOB
            pthread_barrier_wait(args->brrr);
            // next round
            ++count;
            ++j;
            *args->prev2 = *args->prev1;
            *args->prev1 = *output;
            pthread_barrier_wait(args->brrr);
        }
        count = 0;
        i += width;
        j = args->j;
        ++scrape_count;
    }
}

void *update_cell_scraping_tail(void *args_)
{
    static pthread_mutex_t cout_lock;
    pthread_mutex_init(&cout_lock, NULL);
    hmm_arg_type3 *args = (hmm_arg_type3 *)args_;
    const std::vector<int> &seq_i = args->seq_i;
    const std::vector<int> &seq_j = args->seq_j;
    const std::vector<double> &qbases = args->qbases;
    const double &Qi = args->Qi;
    const double &Qd = args->Qd;
    const double &Qg = args->Qg;
    const int &num_emissions_i = args->num_emissions_i;
    const int &num_emissions_j = args->num_emissions_j;
    hmm_cell *north = args->north;
    hmm_cell *northwest = args->northwest;
    hmm_cell *west = args->west;
    hmm_cell *output = args->output;
    // hopefully achieves better cache locality/sharing
    int i = args->i;
    int j = args->j;
    int &width = args->width;
    std::vector<hmm_cell> &last_row = args->last_row;
    int count = 0;
    int scrape_count = 0;
    while (scrape_count < args->num_scrapes)
    {
        // pass j dimension once
        *args->prev2 = hmm_cell();
        *args->prev1 = hmm_cell();
        *output = hmm_cell();
        while (count < 2 * num_emissions_j)
        {
            if (j > 0 && j < num_emissions_j + 1 && i < num_emissions_i + 1)
            {
                output->i_val = Qg * north->i_val + Qi * north->m_val;
                output->j_val = Qg * west->j_val + Qd * west->m_val;
                
                double prior = (seq_i[i] == seq_j[j]) ? 1 - qbases[j] : qbases[j];
                double i_result = (1 - Qg) * northwest->i_val;        // memo_i[i - 1][j - 1];
                double j_result = (1 - Qg) * northwest->j_val;        // memo_j[i - 1][j - 1];
                double m_result = (1 - (Qi + Qd)) * northwest->m_val; // memo_m[i - 1][j - 1];
                output->m_val = prior * (m_result + i_result + j_result);
                debug_log(i, j, *output);
                pthread_barrier_wait(args->brrr);
                last_row[j] = *output;
            }
            else
            {
                // no computation if j is non-negative or OOB or i OOB
                pthread_barrier_wait(args->brrr);
            }
            // next round
            ++count;
            ++j;
            *args->prev2 = *args->prev1;
            *args->prev1 = *output;
            pthread_barrier_wait(args->brrr);
        }
        count = 0;
        i += width;
        j = args->j;
        ++scrape_count;
    }
}
