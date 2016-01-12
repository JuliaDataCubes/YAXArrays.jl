import cablab
import datetime
import numpy

class MiniCubeProvider(cablab.CubeSourceProvider):

    def __init__(self, cube_config):
        if cube_config.grid_width != 6 or cube_config.grid_height != 3:
            raise ValueError('illegal cube configuration, cube dimension must be 6x3')

    def prepare(self):
        return None

    def get_temporal_coverage(self):
        return (datetime.datetime(2000, 1, 1, 0, 0), datetime.datetime(2005, 1, 1, 0, 0))


    def get_spatial_coverage(self):
        return 0, 0, 6, 3

    def get_variable_descriptors(self):
        return {
            'Float_Var': {
                'data_type': numpy.float32,
                'fill_value': -9999.0,
                'units': '-',
                'long_name': 'Some variable',
                'scale_factor': 1.0,
                'add_offset': 0.0,
            },
            'Int_Var': {
                'data_type': numpy.int32,
                'fill_value': -1,
                'units': '-',
                'long_name': 'An integer variable',
                'scale_factor': 1.0,
                'add_offset': 0.0,
            }
        }

    def compute_variable_images(self, period_start, period_end):
        print(period_start)
        print(period_end)
        ims = []
        #First create a Float variable
        x=numpy.zeros((3,6))
        x[0,0]=period_start.year
        x[0,1]=period_start.month
        x[0,2]=period_start.day
        x[0,3]=period_end.year
        x[0,4]=period_end.month
        x[0,5]=period_end.day
        #Create some other values
        x[1,:]=range(1,7)
        #Fill some NaNs and missings
        x[2,1:2]=numpy.nan
        x[2,3:4]=-9999.0
        ims.append(x)
        #Now make an Int variable (e.g. for categories?)
        x=numpy.zeros((3,6),dtype=numpy.int32)
        x[0,0]=period_start.year
        x[0,1]=period_start.month
        x[0,2]=period_start.day
        x[0,3]=period_end.year
        x[0,4]=period_end.month
        x[0,5]=period_end.day
        #Create some other values
        x[1,:]=range(1,7)
        #Fill some NaNs and missings
        x[2,1:4]=-1
        ims.append(x)
        varnames=['Float_Var','Int_Var']
        return {varnames[i]: ims[i] for i in range(0,2)}

    def close(self):
        return 1

if __name__ == "__main__":
    import sys
    cube = cablab.Cube.create(sys.argv[1], cablab.CubeConfig(spatial_res=60.0,grid_width=6,grid_height=3,temporal_res=200,end_time=datetime.datetime(2006,1,1)))
    cube.update(MiniCubeProvider(cube.config))
