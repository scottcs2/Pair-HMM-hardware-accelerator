#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <string>
#include "hmm.h"
#include "pair_hmm.h"
 
using namespace std;

int main(int argc, char **argv) {
    ifstream is;
    is.open("test.multi.data");
    PairHMM_Multi phmmm(is);
    // phmmm.enable_verbose();
    phmmm.forward_alg();
    phmmm.forward_alg_multi();
    cout << "NO MEMO VERSIONS-----" << endl;
    phmmm.forward_alg_no_memo();
    phmmm.forward_alg_multi_no_memo();
    phmmm.forward_alg_multi_group_no_memo(2);
    phmmm.forward_alg_multi_group_no_memo(5);
    phmmm.forward_alg_multi_group_no_memo(10);
    phmmm.forward_alg_multi_group_no_memo(25);
    phmmm.forward_alg_multi_group_no_memo(50);
    is.close();
    return 0;
}
