#include "pair_hmm.h"

using namespace std;

#ifdef DEBUG
vector<vector<hmm_cell>> debug;
#endif

void debug_init(int i, int j)
{
#ifdef DEBUG
    debug = vector<vector<hmm_cell>>(i, vector<hmm_cell>(j));
#endif
} 
void debug_log(int i, int j, hmm_cell data)
{
#ifdef DEBUG
    debug[i][j] = data;
#endif
}
void debug_print()
{
#ifdef DEBUG
    cout << "M MATRIX: " << endl;
    for (auto i : debug)
    {
        for (auto j : i)
        {
            cout << setprecision(5) << setw(15) << j.m_val;
        }
        cout << endl;
    }

    cout << "I MATRIX: " << endl;
    for (auto i : debug)
    {
        for (auto j : i)
        {
            cout << setprecision(5) << setw(15) << j.i_val;
        }
        cout << endl;
    }

    cout << "J MATRIX: " << endl;
    for (auto i : debug)
    {
        for (auto j : i)
        {
            cout << setprecision(5) << setw(15) << j.j_val;
        }
        cout << endl;
    }

    cout << endl;
#endif
}