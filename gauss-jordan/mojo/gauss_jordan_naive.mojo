from memory import UnsafePointer, memcpy, memset
from random import rand
from python import Python, PythonObject
from testing import assert_almost_equal
from time import monotonic as now


struct Matrix[type: DType]:
    var rows: Int
    var cols: Int
    var data: UnsafePointer[Scalar[type]]

    fn __init__(mut self, rows: Int, cols: Int):
        self.rows = rows
        self.cols = cols
        self.data = UnsafePointer[Scalar[type]].alloc(rows * cols)
        memset(self.data, 0, rows * cols)

    fn randomize(mut self, min: Float64 = 0, max: Float64 = 1):
        rand(self.data, self.rows * self.cols, min=min, max=max)

    fn identity_matrix(mut self):
        if self.rows != self.cols:
            return
        for i in range(self.rows):
            for j in range(self.cols):
                if i == j:
                    self[i, j] = 1

    fn __copyinit__(mut self, matrix: Matrix[type]):
        self.rows = matrix.rows
        self.cols = matrix.cols
        self.data = UnsafePointer[Scalar[type]].alloc(matrix.rows * matrix.cols)
        memcpy(self.data, matrix.data, matrix.rows * matrix.cols)

    fn __getitem__(self, row: Int, col: Int) -> Scalar[type]:
        return self.data[row * self.cols + col]

    fn __setitem__(mut self, row: Int, col: Int, value: Scalar[type]):
        self.data[row * self.cols + col] = value

    fn __del__(owned self):
        self.data.free()

    fn __str__(self) -> String:
        var result: String = ""
        for i in range(self.rows):
            for j in range(self.cols):
                result += str(self[i, j]) + " "
            result += "\n"
        return result

    fn num_elements(self) -> Int:
        return self.rows * self.cols


fn gauss_jordan_naive[
    type: DType
](matrix: Matrix[type], mut inverse_matrix: Matrix[type]):
    # We will use the two elementary row operations of scale and add scale of one row to another
    # [A | I] -> [I | A^-1]
    var matrix_modify = matrix

    if matrix.rows != matrix.cols:
        return
    if (
        inverse_matrix.rows != inverse_matrix.cols
        and inverse_matrix.rows != matrix.rows
    ):
        return

    var rows = matrix.rows
    var cols = matrix.cols
    # Gaussian Elimination
    for i in range(rows):
        # Normalize pivot to 1
        var normalize_value = matrix_modify[i, i]
        for j in range(cols):
            matrix_modify[i, j] /= normalize_value
            inverse_matrix[i, j] /= normalize_value

        # apply scale add by row i on the other rows k to make column j of row k equal to 0
        for k in range(i + 1, rows):
            if matrix_modify[k, i] != 0:
                var scale = matrix_modify[k, i] / matrix_modify[i, i]
                scale = matrix_modify[k, i] / matrix_modify[i, i]
                if matrix_modify[k, i] - scale * matrix_modify[i, i] != 0:
                    scale *= -1
    
                for l in range(cols):
                    matrix_modify[k, l] -= scale * matrix_modify[i, l]
                    inverse_matrix[k, l] -= scale * inverse_matrix[i, l]
                    # if i == l:
                    #     matrix_modify[i, l] = abs(matrix_modify[i, l]) # why is mojo putting a value of -0.0 if I don't do this?

    # Jordan Elimination
    for i in range(rows - 1, -1, -1):
        for k in range(i - 1, -1, -1):
            if matrix_modify[k, i] != 0:
                var scale = matrix_modify[k, i] / matrix_modify[i, i]
                if matrix_modify[k, i] - scale * matrix_modify[i, i] != 0:
                    scale *= -1
    
                for l in range(cols):
                    matrix_modify[k, l] -= scale * matrix_modify[i, l]
                    inverse_matrix[k, l] -= scale * inverse_matrix[i, l]


fn to_numpy(matrix: Matrix) raises -> PythonObject:
    var np = Python.import_module("numpy")
    var pyarray: PythonObject = np.empty((matrix.rows, matrix.cols), dtype=np.float32)
    var pointer_d = pyarray.__array_interface__["data"][0].unsafe_get_as_pointer[DType.float32]()
    var d: UnsafePointer[Float32] = matrix.data.bitcast[Float32]()
    memcpy(pointer_d, d, matrix.num_elements())
    return pyarray


fn main() raises:
    matrix = Matrix[DType.float32](100, 100)
    matrix.randomize(-10, 10)

    var inverse_matrix = Matrix[DType.float32](100, 100)
    inverse_matrix.identity_matrix()

    var start = now()
    gauss_jordan_naive(matrix, inverse_matrix)
    print("Time: ", now() - start)

    # compare with numpy inverse
    var np = Python.import_module("numpy")
    np.set_printoptions(precision=4)
    var pyarray: PythonObject = to_numpy(matrix)

    start = now()
    var inverse_pyarray: PythonObject = np.linalg.inv(pyarray)
    print("Time: ", now() - start)

    for i in range(matrix.rows):
        for j in range(matrix.cols):
            var value_1 = inverse_matrix[i, j]
            var value_2 = float(inverse_pyarray[i, j]).cast[DType.float32]()
            assert_almost_equal(value_1, value_2, atol=1e-4)