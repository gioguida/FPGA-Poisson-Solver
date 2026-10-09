#ifndef DATA_HPP
#define DATA_HPP

template <class RealType>
struct Discretization {
    int nx;
    int ny;
    int N;
    RealType dx; 
    RealType tol;
    int iters;  
};

template <class RealType>
class Field {
    public:
        // constructors
        Field() : ptr_(0), xdim_(0), ydim_(0) {}
        Field(int xdim, int ydim) : xdim_(xdim), ydim_(ydim) {
            ptr_ = new RealType[xdim*ydim];
        }
        // desctructor
        ~Field() { free(); }
        // initialization
        void init(int xdim, int ydim) {
            free();
            ptr_ = new RealType[xdim*ydim];
            xdim_ = xdim;
            ydim_ = ydim;
        }
        // getters
        RealType* data() { return ptr_; }
        const RealType* data() const { return ptr_; }
        int xdim() const { return xdim_; }
        int ydim() const { return ydim_; }
        int length() const { return xdim_*ydim_; }

        // access via (i,j) pair
        inline RealType& operator() (int i, int j) {
            return ptr_[i+j*xdim_];
        }
        inline RealType const& operator() (int i, int j) const {
            return ptr_[i+j*xdim_];
        }

        // access as a 1D field
        inline RealType & operator[] (int i) {
            return ptr_[i];
        }
        inline RealType const& operator[] (int i) const {
            return ptr_[i];
        }
    
    private:

        void free() {
            if (ptr_) delete[] ptr_;
            ptr_ = 0;
        }

        RealType * ptr_;
        int xdim_;
        int ydim_;
};
#endif
