#ifndef DATA_HPP
#define DATA_HPP

template <class RealType, class IntegerType>
struct Discretization {
    IntegerType nx;
    IntegerType ny;
    IntegerType N;
    RealType dx; 
    RealType tol;
    IntegerType iters;  
};

template <class RealType, class IntegerType>
class Field {
    public:
        // constructors
        Field() : ptr_(0), xdim_(0), ydim_(0) {}
        Field(IntegerType xdim, IntegerType ydim) : xdim_(xdim), ydim_(ydim) {
            ptr_ = new RealType[xdim*ydim];
        }
        // desctructor
        ~Field() { free(); }
        // initialization
        void init(IntegerType xdim, IntegerType ydim) {
            free();
            ptr_ = new RealType[xdim*ydim];
            xdim_ = xdim;
            ydim_ = ydim;
        }
        // getters
        RealType* data() { return ptr_; }
        const RealType* data() const { return ptr_; }
        IntegerType xdim() const { return xdim_; }
        IntegerType ydim() const { return ydim_; }
        IntegerType length() const { return xdim_*ydim_; }

        // access via (i,j) pair
        inline RealType& operator() (IntegerType i, IntegerType j) {
            return ptr_[i+j*xdim_];
        }
        inline RealType const& operator() (IntegerType i, IntegerType j) const {
            return ptr_[i+j*xdim_];
        }

        // access as a 1D field
        inline RealType & operator[] (IntegerType i) {
            return ptr_[i];
        }
        inline RealType const& operator[] (IntegerType i) const {
            return ptr_[i];
        }
    
    private:

        void free() {
            if (ptr_) delete[] ptr_;
            ptr_ = 0;
        }

        RealType * ptr_;
        IntegerType xdim_;
        IntegerType ydim_;
};
#endif