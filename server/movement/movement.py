

class MovementProcessor():

    def __init__(self, sensitivity=4000):
        self.sensitivity = sensitivity

    def process(self, dx, dy):
        dx_pixel = dx * self.sensitivity
        dy_pixel = dy * self.sensitivity

        return dx_pixel, dy_pixel