

class MovementProcessor():

    def __init__(self, sensitivity=4000):
        self.sensitivity = sensitivity
        self.carry_x = 0.0
        self.carry_y = 0.0

    def process(self, dx, dy):
        self.carry_x += dx * self.sensitivity
        self.carry_y += dy * self.sensitivity

        dx_pixel = int(self.carry_x)
        dy_pixel = int(self.carry_y)

        self.carry_x -= dx_pixel
        self.carry_y -= dy_pixel

        return dx_pixel, dy_pixel
