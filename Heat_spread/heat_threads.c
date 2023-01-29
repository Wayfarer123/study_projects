#include <pthread.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <math.h>
#include <string.h>

int left[128];
int right[128];
int N;
int flag = 0;
double H_step;
double T_step;
double T;
int numbers[128] = {0};
int T_N = 1;

double *u0;
double *u1;

pthread_barrier_t b;

void* iter(void* n){
    double cur = 0;
    while (cur < T) {
        pthread_barrier_wait(&b);
        int l_n = *(int*)n;
        if(l_n < 128) {
            int first = left[l_n];
            int last = right[l_n];
            double t = T_step;
            double h = H_step;
            int i = 0;
            if (flag == 0) {
                for (i = first; i < last; i++) {
                    if (i == 0){
                        u1[i] = 0;
                        continue;
                    }
                    if (i == N - 1) {
                        u1[i] = 1;
                        continue;
                    }
                    u1[i] = u0[i] + t*t/h/h*(u0[i-1]+u0[i+1]-2*u0[i]);
                }
            }
            else {
                for (i = first; i < last; i++) {
                    if (i == 0) {
                        u0[i] = 0;
                        continue;
                    }
                    if (i == N - 1) {
                        u0[i] = 1;
                        continue;
                    }
                    u0[i] = u1[i] + t*t/h/h*(u1[i-1]+u1[i+1]-2*u1[i]);
                }
            }
            pthread_barrier_wait(&b);
            if (l_n == T_N - 1){
                if (flag == 0) {
                    flag = 1;
                }
                else {
                    flag = 0;
                }
            }
            cur+=t;
        }
    }
    pthread_exit(NULL);
}




int main(int argc, char **argv) {
    int i = 0;
    struct timeval starttime, endtime;
    gettimeofday(&starttime, NULL);
    long long t1, t2;
    t1 = starttime.tv_sec * 1000000 + starttime.tv_usec;

    for (i = 0; i < 128; i++) {
        numbers[i] = i;
    }

    if (argv[3]) {
        int n = strtol(argv[1], NULL, 10);
        N = n;
        double t = strtod(argv[2], NULL);
        T = t;
        int P = strtol(argv[3], NULL, 10);
        T_N = P;
        double h_step = (double)1/N;
        H_step = h_step;
        double t_step = sqrt(h_step*h_step*0.3);
        T_step = t_step;


        pthread_barrier_init(&b, NULL, P);

        int number = (int)n/P;
        int last_number = n - (P-1)*number;

        u0 = (double*)malloc(sizeof(double)*(N+1));
        u1 = (double*)malloc(sizeof(double)*(N+1));
        memset(u0, 0, sizeof(double)*(N+1));
        memset(u1, 0, sizeof(double)*(N+1));
        u0[n-1] = 1;
        u1[n-1] = 0;

        pthread_t *thr = (pthread_t*)malloc(sizeof(pthread_t)*(P+1));

        int k = 0;
        for (i = 0; i < P; i++) {
            left[i] = k;
            if (i == P - 1) {
                right[i] = k + last_number;
            }
            else {
                right[i] = k + number;
            k += number;
            }
        }

        int j = 0;
        for (j = 0; j < P; j++) {
            int temp = j;
            pthread_create(&thr[temp], NULL, iter, (void*)&numbers[temp]);
        }


         for (i = 0; i < P; i++){
                pthread_join(thr[i], NULL);
        }

        FILE* f = fopen("ans.txt", "w");

        if (flag == 1) {
            for (i = 0; i < N; i++) {
                fprintf(f, "%lf %lf\n", h_step*i, u1[i]);
            }
        }
        else {
            for (i = 0; i < N; i++) {
                fprintf(f, "%lf %lf\n", h_step*i, u0[i]);
            }
        }


        gettimeofday(&endtime, NULL);
        t2 = endtime.tv_sec * 1000000 + endtime.tv_usec;
        printf("%lld", t2-t1);

        free(u0);
        free(u1);
        free(thr);
        return 0;
    }
    else {
        printf("too few arguments passed");
        return 0;
    }
}
