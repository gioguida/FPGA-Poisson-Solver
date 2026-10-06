#ifndef DATA_HPP
#define DATA_HPP

struct Discretization {
    int nx;
    int ny;
    int N;
    double dx; 
    int iters;  
};

class Field {
    public:
        // constructors
        Field() : ptr_(0), xdim_(0), ydim_(0) {}
        Field(int xdim, int ydim) : xdim_(xdim), ydim_(ydim) {
            ptr_ = new double[xdim*ydim];
        }
        // desctructor
        ~Field() { free(); }
        // initialization
        void init(int xdim, int ydim) {
            free();
            ptr_ = new double[xdim*ydim];
            xdim_ = xdim;
            ydim_ = ydim;
        }
        // getters
        double* data() { return ptr_; }
        const double* data() const { return ptr_; }
        int xdim() const { return xdim_; }
        int ydim() const { return ydim_; }
        int length() const { return xdim_*ydim_; }

        // access via (i,j) pair
        inline double& operator() (int i, int j) {
            return ptr_[i+j*xdim_];
        }
        inline double const& operator() (int i, int j) const {
            return ptr_[i+j*xdim_];
        }

        // access as a 1D field
        inline double & operator[] (int i) {
            return ptr_[i];
        }
        inline double const& operator[] (int i) const {
            return ptr_[i];
        }
    
    private:

        void free() {
            if (ptr_) delete[] ptr_;
            ptr_ = 0;
        }

        double * ptr_;
        int xdim_;
        int ydim_;
};

extern Field u;
extern Field bndN, bndE, bndS, bndW;
extern Discretization options;


#endif