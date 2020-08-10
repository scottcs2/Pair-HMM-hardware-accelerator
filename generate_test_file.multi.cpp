#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <time.h>

using namespace std;

/*
    Should read in randomization parameters from params.data
    And generate an output (with timestamp) in test.data
*/

/*  PARAMS.WSSV FORMAT
refReadLengthMin # (int)
refReadLengthMax # (int)
expReadLengthMin # (int)
expReadLengthMax # (int)
expReadPermsMin # (int)
expReadPermsMax # (int)
expReads # (int)
qscoreMin ASCII
qscoreMax ASCII
qiMin # (FP)
qiMax # (FP)
qdMin # (FP)
qdMax # (FP)
qgMin # (FP)
qgMax # (FP)
*/

/*  TEST.DATA FORMAT
Timestamp
MULTI
NUMHAPLOTYPES
refReadLength
refRead-->

Qi
Qd
Qg
expReadLength
expRead -->
qscores -->

<repeat>
*/

struct ParamStruct
{
    int refReadLengthMin;
    int refReadLengthMax;
    int expReadLengthMin;
    int expReadLengthMax;
    int expReadPermsMin;
    int expReadPermsMax;
    int expReads;
    char qscoreMin;
    char qscoreMax;
    double qiMin;
    double qiMax;
    double qdMin;
    double qdMax;
    double qgMin;
    double qgMax;
};

char bases[4] = {'A', 'C', 'G', 'T'};

int main()
{
    srand(time(NULL));

    int refReadLength, expReadLength;
    string refRead;
    double qi, qd, qg;

    ofstream testFile("test.multi.data", ios::out | ios::trunc);

    cout << "random multi generation" << endl;

    ParamStruct ps;

    fstream params;
    params.open("params.multi.wssv", ios::in);

    // read from params.data (yes i know this is ugly)
    string tmp;
    params >> tmp >> ps.refReadLengthMin >> tmp >> ps.refReadLengthMax;
    params >> tmp >> ps.expReadLengthMin >> tmp >> ps.expReadLengthMax;
    params >> tmp >> ps.expReadPermsMin >> tmp >> ps.expReadPermsMax;
    params >> tmp >> ps.expReads;
    params >> tmp >> ps.qscoreMin >> tmp >> ps.qscoreMax;
    params >> tmp >> ps.qiMin >> tmp >> ps.qiMax;
    params >> tmp >> ps.qdMin >> tmp >> ps.qdMax;
    params >> tmp >> ps.qgMin >> tmp >> ps.qgMax;

    cout << "===RANDOMIZATION PARAMS===" << endl;
    cout << "\trefReadLengthMin: " << ps.refReadLengthMin << endl;
    cout << "\trefReadLengthMax: " << ps.refReadLengthMax << endl;
    cout << "\texpReadLengthMin: " << ps.expReadLengthMin << endl;
    cout << "\texpReadLengthMax: " << ps.expReadLengthMax << endl;
    cout << "\texpReadPermsMin: " << ps.expReadPermsMin << endl;
    cout << "\texpReadPermsMax: " << ps.expReadPermsMax << endl;
    cout << "\texpReads: " << ps.qscoreMin << endl;
    cout << "\tqscoreMin: " << ps.qscoreMin << endl;
    cout << "\tqscoreMax: " << ps.qscoreMax << endl;
    cout << "\tqiMin: " << ps.qiMin << endl;
    cout << "\tqiMax: " << ps.qiMax << endl;
    cout << "\tqdMin: " << ps.qdMin << endl;
    cout << "\tqdMax: " << ps.qdMax << endl;
    cout << "\tqgMin: " << ps.qgMin << endl;
    cout << "\tqgMax: " << ps.qgMax << endl;

    params.close();

    time_t my_time = time(NULL);
    testFile << ctime(&my_time);
    testFile << "MULTI" << endl;

    int random = rand();
    refReadLength = ps.refReadLengthMin + (random % (ps.refReadLengthMax - ps.refReadLengthMin + 1));
    for (int i = 0; i < refReadLength; ++i)
        refRead += bases[rand() % 4];
    testFile << refReadLength << endl;
    testFile << refRead << endl;

    int numReads = ps.expReadPermsMin + (random % (ps.expReadPermsMax - ps.expReadPermsMin + 1));
    testFile << numReads << endl;

    string expRead, qscores;
    for (int i = 0; i < numReads; ++i)
    {
        random = rand();
        expReadLength = ps.expReadLengthMin + (random % (ps.expReadLengthMax - ps.expReadLengthMin + 1));
        for (int j = 0; j < expReadLength; ++j)
        {
            expRead += bases[rand() % 4];
            qscores += char(rand() % 40 + 40);
        }
        random = rand() % 100;
        qi = ps.qiMin + (random * ((ps.qiMax - ps.qiMin) / 100));
        random = rand() % 100;
        qd = ps.qdMin + (random * ((ps.qdMax - ps.qdMin) / 100));
        random = rand() % 100;
        qg = ps.qgMin + (random * ((ps.qgMax - ps.qgMin) / 100));
        // print everything to test.data
        testFile << qi << " ";
        testFile << qd << " ";
        testFile << qg << " ";
        testFile << endl << expReadLength << endl;
        testFile << expRead << endl;
        testFile << qscores << endl;
        expRead.clear();
        qscores.clear();
    }

    testFile.close();

    cout << "DONE" << endl;

    return 0;
}
