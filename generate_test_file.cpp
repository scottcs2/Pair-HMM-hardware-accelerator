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
refReadLength,expReadLength, Qi, Qd, Qg
refRead -->
expRead -->
qscores -->
*/

struct ParamStruct {
    int refReadLengthMin;
    int refReadLengthMax;
    int expReadLengthMin;
    int expReadLengthMax;
    char qscoreMin;
    char qscoreMax;
    double qiMin;
    double qiMax;
    double qdMin;
    double qdMax;
    double qgMin;
    double qgMax;
};

char bases[4] = {'A','C','G','T'};

int main() {

    srand(time(NULL));
    
    int refReadLength, expReadLength;
    string refRead, expRead, qscores;
    double qi, qd, qg;

    ofstream testFile("test.data", ios::out | ios::trunc);

    char sel;
    cout << "Press 1 to generate random data or 2 to enter manually" << endl;
    cin >> sel;

    if(sel == '1') {
        cout << "random" << endl;
    
        ParamStruct ps;

        fstream params;
        params.open("params.wssv", ios::in);

        // read from params.data (yes i know this is ugly)
        string tmp;
        params >> tmp >> ps.refReadLengthMin >> tmp >> ps.refReadLengthMax;
        params >> tmp >> ps.expReadLengthMin >> tmp >> ps.expReadLengthMax;
        params >> tmp >> ps.qscoreMin >> tmp >> ps.qscoreMax;
        params >> tmp >> ps.qiMin >> tmp >> ps.qiMax;
        params >> tmp >> ps.qdMin >> tmp >> ps.qdMax;
        params >> tmp >> ps.qgMin >> tmp >> ps.qgMax;

        cout << "===RANDOMIZATION PARAMS===" << endl;
        cout << "\trefReadLengthMin: " << ps.refReadLengthMin << endl;
        cout << "\trefReadLengthMax: " << ps.refReadLengthMax << endl;
        cout << "\texpReadLengthMin: " << ps.expReadLengthMin << endl;
        cout << "\texpReadLengthMax: " << ps.expReadLengthMax << endl;
        cout << "\tqscoreMin: " << ps.qscoreMin << endl;
        cout << "\tqscoreMax: " << ps.qscoreMax << endl;
        cout << "\tqiMin: " << ps.qiMin << endl;
        cout << "\tqiMax: " << ps.qiMax << endl;
        cout << "\tqdMin: " << ps.qdMin << endl;
        cout << "\tqdMax: " << ps.qdMax << endl;
        cout << "\tqgMin: " << ps.qgMin << endl;
        cout << "\tqgMax: " << ps.qgMax << endl;

        params.close();

        int random = rand() % 100;
        refReadLength = ps.refReadLengthMin + (random * ((ps.refReadLengthMax - ps.refReadLengthMin) / 100));
        
        random = rand() % 100;
        expReadLength = ps.expReadLengthMin + (random * ((ps.expReadLengthMax - ps.expReadLengthMin) / 100));
        
        for(int i = 0; i < refReadLength; ++i) {
            refRead += bases[rand() % 4];
        }

        for(int j = 0; j < expReadLength; ++j) {
            expRead += bases[rand() % 4];   
            qscores += char(rand() % 40 + 40);         
        }

        random = rand() % 100;
        qi = ps.qiMin + (random * ((ps.qiMax - ps.qiMin) / 100));

        random = rand() % 100;
        qd = ps.qdMin + (random * ((ps.qdMax - ps.qdMin) / 100));

        random = rand() % 100;
        qg = ps.qgMin + (random * ((ps.qgMax - ps.qgMin) / 100));


    } else {
        cout << "manual" << endl;
        cout << "Enter reference read" << endl;
        cin >> refRead;
        refReadLength = refRead.length();

        cout << "Enter experimental read" << endl;
        cin >> expRead;
        expReadLength = expRead.length();

        cout << "Enter Qbase scores for exp read" << endl;
        cin >> qscores;

        cout << "Enter Qi" << endl;
        cin >> qi;
        
        cout << "Enter Qd" << endl;
        cin >> qd;
        
        cout << "Enter Qg" << endl;
        cin >> qg;
    }
    
    cout << "Generating output file..." << endl;


    // print everything to test.data
    time_t my_time = time(NULL);
    testFile << ctime(&my_time);
    testFile << refReadLength << endl; 
    testFile << expReadLength << endl;
    testFile << qi << endl;
    testFile << qd << endl;
    testFile << qg << endl;
    testFile << refRead << endl;
    testFile << expRead << endl;
    testFile << qscores << endl; 

    testFile.close();  

    cout << "DONE" << endl;

    return 0;
}

