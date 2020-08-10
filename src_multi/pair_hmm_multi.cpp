#include "pair_hmm.h"

using namespace std;

PairHMM_Multi::PairHMM_Multi(istream &is) : verbose(false)
{
    string str;
    getline(is, str);
    getline(is, str);
    int n;
    is >> n;
    reference_read.reserve(n + 1);
    reference_read.push_back(4);
    is >> str;
    for (int i = 0; i < n; i++)
    {
        switch (str[i])
        {
        case 'T':
            reference_read.push_back(0);
            break;
        case 'C':
            reference_read.push_back(1);
            break;
        case 'G':
            reference_read.push_back(2);
            break;
        case 'A':
            reference_read.push_back(3);
            break;
        case '-':
            reference_read.push_back(4);
            break;
        }
    }
    // (T,C,G,A,-) = (0,1,2,3,4)
    is >> n;
    for (int i = 0; i < n; ++i)
    {
        add_batch(is);
    }
}

void PairHMM_Multi::enable_verbose()
{
    verbose = true;
}

bool PairHMM_Multi::add_batch(std::istream &is)
{
    batches.push_back(haplo_data());
    haplo_data &d = batches.back();
    is >> d.Qi >> d.Qd >> d.Qg;
    int n;
    is >> n;
    string ref;
    is >> ref;
    d.exp.reserve(n + 1);
    d.exp.push_back(4);
    for (int i = 0; i < n; i++)
    {
        switch (ref[i])
        {
        case 'T':
            d.exp.push_back(0);
            break;
        case 'C':
            d.exp.push_back(1);
            break;
        case 'G':
            d.exp.push_back(2);
            break;
        case 'A':
            d.exp.push_back(3);
            break;
        case '-':
            d.exp.push_back(4);
            break;
        }
    }
    // (T,C,G,A,-) = (0,1,2,3,4)

    string qbases_str;
    is >> qbases_str;
    d.qbases.reserve(n + 1);
    d.qbases.push_back(0);
    for (int i = 0; i < qbases_str.length(); i++)
    {
        double converted = pow(10, -0.1 * qbases_str[i]);
        d.qbases.push_back(converted);
    }
}

size_t PairHMM_Multi::max_batch_size()
{
    size_t max_ = 0;
    for (int i = 0; i < batches.size(); ++i)
    {
        max_ = max(max_, batches[i].exp.size());
    }
    return max_;
}

int PairHMM_Multi::forward_alg()
{
    const vector<int> &seq_i = reference_read;
    const int num_emissions_i = seq_i.size() - 1;
    vector<vector<double>> memo_m, memo_i, memo_j;
    // initialize memos to all 0's (IxJ)
    memo_m = memo_i = memo_j = vector<vector<double>>(num_emissions_i + 1, vector<double>(max_batch_size() + 1, 0.0));
    vector<double> results(batches.size(), 0.0);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    // initial state
    memo_m[0][0] = 1;
    for (int e = 0; e < batches.size(); ++e)
    {
        const haplo_data &haplo = batches[e];
        const vector<int> &seq_j = haplo.exp;
        const int num_emissions_j = seq_j.size() - 1;
        for (int i = 1; i <= num_emissions_i; ++i)
        {
            for (int j = 1; j <= num_emissions_j; ++j)
            {
                // compute j (D) matrix
                memo_j[i][j] = haplo.Qd * memo_m[i][j - 1] + haplo.Qg * memo_j[i][j - 1];
                // compute i matrix
                memo_i[i][j] = haplo.Qi * memo_m[i - 1][j] + haplo.Qg * memo_i[i - 1][j];
                // compute m matrix
                double prior = (seq_i[i] == seq_j[j]) ? 1 - haplo.qbases[j] : haplo.qbases[j];
                double m_result = (1 - (haplo.Qi + haplo.Qd)) * memo_m[i - 1][j - 1];
                double i_result = (1 - haplo.Qg) * memo_i[i - 1][j - 1];
                double j_result = (1 - haplo.Qg) * memo_j[i - 1][j - 1];
                memo_m[i][j] = prior * (m_result + i_result + j_result);
            }
        }
        results[e] = memo_m[num_emissions_i][num_emissions_j] +
                     memo_i[num_emissions_i][num_emissions_j] +
                     memo_j[num_emissions_i][num_emissions_j];
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    int best_index = 0;
    double best = 0.0;

    cout << "SEQUENTIAL FORWARD ALGORITHM COMPLETE: " << elapsed << " usec" << endl;
    for (int i = 0; i < results.size(); ++i)
    {
        assert(i < results.size());
        if (verbose)
        {
            cout << "\t" << i << ": " << results[i] << endl;
        }
        if (best < results[i])
        {
            best = results[i];
            best_index = i;
        }
    }
    cout << "Highest Score is #" << best_index << ": " << setprecision(6) << best << endl;
    return elapsed;
}

int PairHMM_Multi::forward_alg_no_memo()
{
    const vector<int> &seq_i = reference_read;
    const int num_emissions_i = seq_i.size() - 1;
    vector<hmm_cell> curr, prev;
    // initialize memos to all 0's (IxJ)
    vector<double> results(batches.size(), 0.0);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    // initial state
    for (int e = 0; e < batches.size(); ++e)
    {
        const haplo_data &haplo = batches[e];
        const vector<int> &seq_j = haplo.exp;
        const int num_emissions_j = seq_j.size() - 1;
        curr = prev = vector<hmm_cell>(num_emissions_j + 1);
        prev[0].m_val = 1;
        for (int i = 1; i <= num_emissions_i; ++i)
        {
            for (int j = 1; j <= num_emissions_j; ++j)
            {
                // compute j (D) matrix
                curr[j].j_val = haplo.Qd * curr[j - 1].m_val + haplo.Qg * curr[j - 1].j_val;
                // compute i matrix
                curr[j].i_val = haplo.Qi * prev[j].m_val + haplo.Qg * prev[j].i_val;
                // compute m matrix
                double prior = (seq_i[i] == seq_j[j]) ? 1 - haplo.qbases[j] : haplo.qbases[j];
                double m_result = (1 - (haplo.Qi + haplo.Qd)) * prev[j - 1].m_val;
                double i_result = (1 - haplo.Qg) * prev[j - 1].i_val;
                double j_result = (1 - haplo.Qg) * prev[j - 1].j_val;
                curr[j].m_val = prior * (m_result + i_result + j_result);
            }
            prev.swap(curr);
            curr[0] = hmm_cell();
        }
        results[e] = prev.back().i_val +
                     prev.back().j_val +
                     prev.back().m_val;
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    int best_index = 0;
    double best = 0.0;

    cout << "SEQUENTIAL NO MEMO FORWARD ALGORITHM COMPLETE: " << elapsed << " usec" << endl;
    for (int i = 0; i < results.size(); ++i)
    {
        assert(i < results.size());
        if (verbose)
        {
            cout << "\t" << i << ": " << results[i] << endl;
        }
        if (best < results[i])
        {
            best = results[i];
            best_index = i;
        }
    }
    cout << "Highest Score is #" << best_index << ": " << setprecision(6) << best << endl;
    return elapsed;
}

void *forward_alg_multiT(void *);
int PairHMM_Multi::forward_alg_multi()
{
    const vector<int> &seq_i = reference_read;
    const int num_emissions_i = seq_i.size() - 1;
    vector<double> results(batches.size(), 0.0);

    pthread_t *threads = new pthread_t[batches.size()];
    hmm_arg_type4 **args = new hmm_arg_type4 *[batches.size()];

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    for (int e = 0; e < batches.size(); ++e)
    {
        args[e] = new hmm_arg_type4{seq_i, &batches[e], &results[e]};
        pthread_create(threads + e, NULL, forward_alg_multiT, args[e]);
    }
    for (int i = 0; i < batches.size(); ++i)
    {
        pthread_join(threads[i], NULL);
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    int best_index = 0;
    double best = 0.0;
    cout << "PTHREAD FORWARD ALGORITHM COMPLETE: " << elapsed << " usec" << endl;
    for (int i = 0; i < results.size(); ++i)
    {
        if (verbose)
        {
            cout << "\t" << i << ": " << results[i] << endl;
        }
        if (best < results[i])
        {
            best = results[i];
            best_index = i;
        }
    }
    cout << "Highest Score is #" << best_index << ": " << setprecision(6) << best << endl;
    for (int i = 0; i < batches.size(); ++i)
    {
        delete args[i];
    }
    delete[] threads, args;
    return elapsed;
}

void *forward_alg_multiT2(void *);
int PairHMM_Multi::forward_alg_multi_no_memo()
{
    const vector<int> &seq_i = reference_read;
    const int num_emissions_i = seq_i.size() - 1;
    vector<double> results(batches.size(), 0.0);

    pthread_t *threads = new pthread_t[batches.size()];
    hmm_arg_type4 **args = new hmm_arg_type4 *[batches.size()];

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    for (int e = 0; e < batches.size(); ++e)
    {
        args[e] = new hmm_arg_type4{seq_i, &batches[e], &results[e]};
        pthread_create(threads + e, NULL, forward_alg_multiT2, args[e]);
    }
    for (int i = 0; i < batches.size(); ++i)
    {
        pthread_join(threads[i], NULL);
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    int best_index = 0;
    double best = 0.0;
    cout << "PTHREAD (NO-MEMO) FORWARD ALGORITHM COMPLETE: " << elapsed << " usec" << endl;
    for (int i = 0; i < results.size(); ++i)
    {
        if (verbose)
        {
            cout << "\t" << i << ": " << results[i] << endl;
        }
        if (best < results[i])
        {
            best = results[i];
            best_index = i;
        }
    }
    cout << "Highest Score is #" << best_index << ": " << setprecision(6) << best << endl;

    for (int i = 0; i < batches.size(); ++i)
    {
        delete args[i];
    }
    delete[] threads, args;
    return elapsed;
}

void *forward_alg_multiT3(void *);
int PairHMM_Multi::forward_alg_multi_group_no_memo(int num_groups)
{
    if (num_groups == 1)
    {
        cout << "forward_alg must run with more than 1 group" << endl;
        return -1;
    }

    const vector<int> &seq_i = reference_read;
    const int num_emissions_i = seq_i.size() - 1;
    vector<double> results(batches.size(), 0.0);

    pthread_t *threads = new pthread_t[num_groups];
    hmm_arg_type5 **args = new hmm_arg_type5 *[num_groups];

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t start = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    // Begin Critical Section
    int reads_per_group = batches.size() / num_groups;
    int leftover = batches.size() % num_groups;
    for (int e = 0; e < num_groups; ++e)
    {
        if (e != num_groups - 1)
        {
            args[e] = new hmm_arg_type5{seq_i,
                                        &batches[e * reads_per_group], &batches[(e + 1) * reads_per_group],
                                        &results[e * reads_per_group], &results[(e + 1) * reads_per_group]};
        }
        else
        {
            args[e] = new hmm_arg_type5{seq_i,
                                        &batches[e * reads_per_group], &batches[e * reads_per_group + leftover],
                                        &results[e * reads_per_group], &results[e * reads_per_group + leftover]};
        }

        pthread_create(threads + e, NULL, forward_alg_multiT3, args[e]);
    }
    for (int i = 0; i < num_groups; ++i)
    {
        pthread_join(threads[i], NULL);
    }
    // End Critical Section
    gettimeofday(&tv, NULL);
    uint64_t end = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
    uint64_t elapsed = end - start;

    int best_index = 0;
    double best = 0.0;
    cout << "PTHREAD " << num_groups << " GROUPS (NO-MEMO) FORWARD ALGORITHM COMPLETE: " << elapsed << " usec" << endl;
    for (int i = 0; i < results.size(); ++i)
    {
        if (verbose)
        {
            cout << "\t" << i << ": " << results[i] << endl;
        }
        if (best < results[i])
        {
            best = results[i];
            best_index = i;
        }
    }
    cout << "Highest Score is #" << best_index << ": " << setprecision(6) << best << endl;

    for (int i = 0; i < num_groups; ++i)
    {
        delete args[i];
    }
    delete[] threads, args;
    return elapsed;
}

void *PairHMM_Multi::forward_alg_multiT(void *args_)
{
    hmm_arg_type4 *args = (hmm_arg_type4 *)args_;
    const vector<int> &seq_i = args->seq_i;
    const haplo_data &haplo = *args->hd;
    const int num_emissions_i = seq_i.size() - 1;
    vector<vector<double>> memo_m, memo_i, memo_j;
    memo_m = memo_i = memo_j = vector<vector<double>>(num_emissions_i + 1, vector<double>(haplo.exp.size() + 1, 0.0));
    memo_m[0][0] = 1;
    const vector<int> &seq_j = haplo.exp;
    const int num_emissions_j = seq_j.size() - 1;
    for (int i = 1; i <= num_emissions_i; ++i)
    {
        for (int j = 1; j <= num_emissions_j; ++j)
        {
            // compute j (D) matrix
            memo_j[i][j] = haplo.Qd * memo_m[i][j - 1] + haplo.Qg * memo_j[i][j - 1];
            // compute i matrix
            memo_i[i][j] = haplo.Qi * memo_m[i - 1][j] + haplo.Qg * memo_i[i - 1][j];
            // compute m matrix
            double prior = (seq_i[i] == seq_j[j]) ? 1 - haplo.qbases[j] : haplo.qbases[j];
            double m_result = (1 - (haplo.Qi + haplo.Qd)) * memo_m[i - 1][j - 1];
            double i_result = (1 - haplo.Qg) * memo_i[i - 1][j - 1];
            double j_result = (1 - haplo.Qg) * memo_j[i - 1][j - 1];
            memo_m[i][j] = prior * (m_result + i_result + j_result);
        }
    }
    *args->result = memo_m[num_emissions_i][num_emissions_j] +
                    memo_i[num_emissions_i][num_emissions_j] +
                    memo_j[num_emissions_i][num_emissions_j];
}

void *PairHMM_Multi::forward_alg_multiT2(void *args_)
{
    hmm_arg_type4 *args = (hmm_arg_type4 *)args_;
    const vector<int> &seq_i = args->seq_i;
    const haplo_data &haplo = *args->hd;
    const int num_emissions_i = seq_i.size() - 1;
    const vector<int> &seq_j = haplo.exp;
    const int num_emissions_j = seq_j.size() - 1;
    vector<hmm_cell> curr, prev;
    curr = prev = vector<hmm_cell>(num_emissions_j + 1);
    prev[0].m_val = 1;
    for (int i = 1; i <= num_emissions_i; ++i)
    {
        for (int j = 1; j <= num_emissions_j; ++j)
        {
            // compute j (D) matrix
            curr[j].j_val = haplo.Qd * curr[j - 1].m_val + haplo.Qg * curr[j - 1].j_val;
            // compute i matrix
            curr[j].i_val = haplo.Qi * prev[j].m_val + haplo.Qg * prev[j].i_val;
            // compute m matrix
            double prior = (seq_i[i] == seq_j[j]) ? 1 - haplo.qbases[j] : haplo.qbases[j];
            double m_result = (1 - (haplo.Qi + haplo.Qd)) * prev[j - 1].m_val;
            double i_result = (1 - haplo.Qg) * prev[j - 1].i_val;
            double j_result = (1 - haplo.Qg) * prev[j - 1].j_val;
            curr[j].m_val = prior * (m_result + i_result + j_result);
        }
        prev.swap(curr);
        curr[0] = hmm_cell();
    }

    *args->result = prev.back().i_val +
                    prev.back().j_val +
                    prev.back().m_val;
    return nullptr;
}

void *PairHMM_Multi::forward_alg_multiT3(void *args_)
{
    hmm_arg_type5 *args = (hmm_arg_type5 *)args_;
    const vector<int> &seq_i = args->seq_i;
    vector<hmm_cell> curr, prev;
    for (auto h = args->hd_begin; h != args->hd_end; ++h)
    {
        const haplo_data &haplo = *h;
        const int num_emissions_i = seq_i.size() - 1;
        const vector<int> &seq_j = haplo.exp;
        const int num_emissions_j = seq_j.size() - 1;
        // initialize memos to all 0's (IxJ)
        curr = prev = vector<hmm_cell>(num_emissions_j + 1);
        prev[0].m_val = 1;
        for (int i = 1; i <= num_emissions_i; ++i)
        {
            for (int j = 1; j <= num_emissions_j; ++j)
            {
                // compute j (D) matrix
                curr[j].j_val = haplo.Qd * curr[j - 1].m_val + haplo.Qg * curr[j - 1].j_val;
                // compute i matrix
                curr[j].i_val = haplo.Qi * prev[j].m_val + haplo.Qg * prev[j].i_val;
                // compute m matrix
                double prior = (seq_i[i] == seq_j[j]) ? 1 - haplo.qbases[j] : haplo.qbases[j];
                double m_result = (1 - (haplo.Qi + haplo.Qd)) * prev[j - 1].m_val;
                double i_result = (1 - haplo.Qg) * prev[j - 1].i_val;
                double j_result = (1 - haplo.Qg) * prev[j - 1].j_val;
                curr[j].m_val = prior * (m_result + i_result + j_result);
            }
            prev.swap(curr);
            curr[0] = hmm_cell();
        }
        *(args->result_begin++) = prev.back().i_val +
                                  prev.back().j_val +
                                  prev.back().m_val;
    }
    return nullptr;
}